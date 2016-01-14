class Booking < ActiveRecord::Base
  include BookingPresenter, SmsGate, PaymentLogic, PhoneNormalizer,
    BookingElasticSearch, ActionController::UrlWriter, ActsAsBooleanTime
  extend Enumerize, RansackerDummy

  ACTIVE_STATES = ['waiting', 'paid', 'serving', 'place_confirmed']
  FINAL_STATES = ['expired', 'overdue', 'cancelled', 'completed']

  ROOM_TITLES = [ 'any', 'smoking', 'nosmoking' ]
  TIME_STATES = [ 'active', 'waiting_list' ]

  SOURCE_KINDS = %w( real dev offline )

  REASONS_FOR_EMAIL_CONFIRMATION = %w( 1 2 )

  TIMENET = 30 # сетка для букинга

  attr_accessible # none
  attr_reader :last_result
  attr_accessor :skip_update_fin_month

  acts_as_boolean_time :checked_at

  enumerize :revenue_type, :in => PAYMENT_KINDS
  enumerize :state, :in => %w(unconfirmed overdue paid serving completed cancelled waiting place_confirmed expired), :scope => true
  enumerize :action, :in => %w(no set_cancelled change_details)

  belongs_to :user
  belongs_to :phone_number, foreign_key: :phone, counter_cache: true
  belongs_to :place, counter_cache: true
  belongs_to :table
  belongs_to :room
  belongs_to :order_room
  belongs_to :operator, :class_name => 'User'
  belongs_to :initial_operator, :class_name => 'User'
  belongs_to :next_booking, :class_name => 'Booking'
  belongs_to :previous_booking, :class_name => 'Booking'
  belongs_to :employee
  belongs_to :reconciliation_responsible, :class_name => 'User'
  belongs_to :reconciliation_employee, :class_name => 'Employee'
  belongs_to :place_selection

  has_one :waiting
  has_one :review
  has_one :booking_revise, inverse_of: :booking
  has_one :user_step, -> { where(kind: 'booking') }, as: :reason
  has_one :forwarder_user_step, -> { where(kind: 'referral_booking') }, as: :reason, :class_name => 'UserStep'

  has_many :smses, :class_name => 'Sms::Sms'
  has_many :billing_invoices, :as => :payable
  has_many :friend_notifications

  accepts_nested_attributes_for :employee

  delegate :title, :alternative_title, :second_alternative_title, :old_title,
    :old_alternative_title, :avg_price, :landing_link, :sms?, :city_id,
    :to => :place, :prefix => true, :allow_nil => true
  delegate :email, :to => :operator, :prefix => true, :allow_nil => true
  delegate :name_with_position, :to => :employee, :prefix => true,
    :allow_nil => true
  delegate :has_negative_review?, :to => :phone_number, :prefix => true, :allow_nil => true


  validates_presence_of :place, :state, :source, :time, :persons
  validates_presence_of :name, :phone, :sum, :url, :if => :common?
  validates_presence_of :table, :if => lambda{ |b| b.place.platform? }

  # необходимо исправить валидатор, он должен быть внутри lambda,
  # но это не работает в Rails 2.3, надо заменить на кастомный валидатор

  unless Rails.env.test?
    validates_inclusion_of :source, :in => Partner.all_sources
  end

  validates_inclusion_of :room_title, :in => ROOM_TITLES, :if => :common?, :allow_blank => true
  validates_inclusion_of :time_state, :in => TIME_STATES, :if => :common?, :allow_blank => true
  validates_inclusion_of :source_kind, :in => SOURCE_KINDS
  validates_numericality_of :persons, :greater_than => 0
  validates_uniqueness_of :widget, :allow_blank => true
  validates_uniqueness_of :yandex_book_id, :allow_blank => true

  validate :next_is_valid, :if => :next_booking
  validate :previous_is_valid, :if => :previous_booking
  validate :prepayment_fewer_deposit, :if => lambda{ |b| b.place.platform? and b.offline? and b.with_deposit? }
  validate_on_create :time_into_timetable
  validate_on_create :time_in_future, :if => :common?
  validate_on_create :ensure_single_booking_by_table, :if => lambda{ |b| b.place.platform? }
  validate_on_create :phone_number_confirmed, :if => :common_widget?
  # добавить антиспам валидатор,не более n броней в сутки по номеру телефона
  # validate_on_create :ensure_single_waiting_booking, :if => :common?

  validate :check_gift_by_promo, :if => lambda{ |b| b.new_record? && b.place_promo_code }

  before_validation :change_booking_date, :if => :time_changed?
  before_validation :reset_operator, :if => :operator_id_changed?
  before_validation :set_source, :if => :phone_channel_changed?
  before_validation_on_create :set_defaults
  before_create :predefine_user
  before_save :change_autocomplete_task, :if => :time_changed?
  before_save :change_source_kind_and_utm, :if => :source_changed?
  before_save :change_notify_task, :if => :time_changed?
  before_save :normalize_phone!, :if => :phone_changed?
  before_save :change_revenue_info, :if => lambda{ |b| b.common? and (b.place_id_changed? or b.persons_changed?) }
  before_save :set_operator_set_at, :if => :operator_id_changed?
  before_destroy :can_destroy?

  after_create :run_expire_task, :if => :with_payment?
  after_create :confirm_and_transfer, :if => lambda{ |b| b.offline? or b.place.call_center? or b.without_prepayment? }
  after_create :update_next_booking, :if => :next_booking
  after_create :hold_gift_item, :if => lambda { |b| b.place_promo_code? }

  after_commit :notify_call_center, :on => :update, :if => :real?
  after_commit :notify_call_center_on_create, :on => :create, :if => :real?

  after_save :change_profile, :if => lambda{ |b| b.phone_changed? or b.place_id_changed? }
  after_save :change_phone_number, :if => :phone_changed?
  after_save :assign_stats_to_user, :if => :user_id_changed?
  after_save :notify_state_change, :if => lambda{ |b| b.transferred_at_was.nil? and b.transferred_at_changed? and (b.place_confirmed? or b.paid?) }
  after_save :update_fin_month, :if => lambda{ |b| !b.skip_update_fin_month and b.financial_month and (b.finance_info_changed? or b.state_changed?) }

  delegate :iphone_app?, :to => :partner, :prefix => true

  state_machine :state, :initial => :waiting do

    after_transition any => :paid do |b, t|
      b.update_attribute :payed_at, b.current_time_zone.now

      # таск, который переводит бронь в состояние completed(нужно если нет платформы)
      # или если на платформе не отмечаю что клиент пришел
      task = b.delay({:run_at => b.time_for_autocomplete_task}).set_autocomplete
      b.update_attribute(:autocomplete_task, task.id)

      if b.notify_me && b.time_for_notify_task > b.current_time_zone.now
        notify_task = b.delay({:run_at => b.time_for_notify_task}).send_notify_sms!
        b.update_attribute(:notify_task, notify_task.id)
      end

      if b.common_undev?
        b.delay.send_sms!(b.phone, b.sms_processing_order) if b.send_processing_sms?
        b.notify_booking_create
        b.delay.send_sms! Settings.callcenter_sms_phones.join(';'), b.sms_callcenter_girl
      end

      AchievementService.new(b).delay.process! if b.source == 'gettable-iphone'

    end

    after_transition any => :serving do |b, t|
      if b.serve_from.blank?
        b.delay({:run_at => b.place.close_time(b.booking_date)}).set_completed
        b.update_attribute :serve_from, b.current_time_zone.now

        if p = b.profile
          p.avg_persons = ((p.avg_persons * p.visits + b.persons).to_f / (p.visits + 1)).round(2)
          p.deposits += b.sum.to_f
          p.visits += 1
          p.last_visit = b.booking_date
          p.save
        end
      end
    end

    after_transition any => :completed do |b, t|
      if b.common? and b.email.present? and !b.yandex?
        Notifier.delay({:run_at => b.time.tomorrow}).booking_review(b)
      end

      if b.partner && b.partner_iphone_app?
        b.delay({:run_at => b.current_time_zone.now + 16.hours}).create_add_to_fav_notification
      end

      b.notify_state_change
      b.relink_my_bookings!
      b.update_attribute :serve_to, b.current_time_zone.now
      b.set_gift_item_used_at if b.place_promo_code?
    end

    after_transition any => :place_confirmed do |b, t|
      # перенести потом и для броней на айпад
      # общая логика когда заведение говорит что места есть и принимает резерв
      # убрать Rails.env.production? если сделаем список дев адресов куда письма локально уходят
      if b.place.employees.working.booking_email_notify.with_email.count > 0 and b.common_undev? and Rails.env.production?
        FinancialNotifier.delay.confirmed_booking b
      end
    end

    after_transition any => :cancelled do |b, t|
      b.__elasticsearch__.update_document if Booking.respond_to?('__elasticsearch__')
      b.relink_my_bookings!
      b.send_cancel_sms if b.cancellation_text.present?
      b.notify_state_change unless b.cancelled_from_yandex?
      b.action_complete unless b.no_actions
      b.update_attribute :cancelled_at, b.current_time_zone.now
      b.unhold_gift_item if b.place_promo_code?
    end

    after_transition any => :overdue do |b, t|
      b.relink_my_bookings!
      b.update_attribute :overdue_at, b.current_time_zone.now
    end

    event :confirm do
      transition :waiting => :paid, :if => lambda { |b| not b.with_payment? }
    end

    event :pay do
      transition :waiting => :paid
    end

    event :serve do
      transition :paid => :serving, :if => lambda { |b| b.place.platform? and b.previous_performed? and not b.table.serving? }
    end

    event :place_confirm do
      transition :paid => :place_confirmed, :if => lambda { |b| b.place.call_center? }
    end

    event :set_fake do
      transition :completed => :overdue
    end

    event :restore do
      transition :overdue => :completed
    end

    event :complete do
      transition [:serving, :place_confirmed] => :completed
    end

    event :cancel do
      transition [:paid, :place_confirmed] => :cancelled
    end

    event :be_late do
      transition :paid => :overdue
    end

    event :expire do
      transition :waiting => :expired
    end

  end

  state_machine :action, :initial => :no do

    after_transition :on => :mark_to_set_cancelled do |b, t|
      if b.common_undev?
        b.delay.send_sms!(Settings.callcenter_sms_phones.join(';'), b.sms_cancel_notify)
      end
    end

    event :action_complete do
      transition all - [ :no ] => :no
    end

    # Аналогично этому методу надо будет сделать:
    # => set_deposit & change_details
    event :mark_to_set_cancelled do
      transition all - [ :set_cancelled ] => :set_cancelled
    end

    state :change_details do
      validate do
        error_type = :no

        if action_params[:time].present? && action_params[:time] < Time.now
          error_type = :time
        end

        if action_params[:persons].present? && !action_params[:persons].between?(place.min_persons, place.max_persons)
          error_type = :persons
        end

        case error_type
        when :time
          errors.add(:base, 'Нельзя выбрать дату, которая уже прошла')
        when :persons
          errors.add(:base, "В данном заведениии можно забронировать столик для #{place.min_persons} - #{place.max_persons} человек")
        else
          return
        end

      end
    end

    event :mark_to_change_details do
      transition all - [ :set_cancelled ] => :change_details
    end

  end

  named_scope :active, :conditions => ['state in (?)', ACTIVE_STATES]
  named_scope :finished, :conditions => ['state in (?)', FINAL_STATES]
  named_scope :completed, :conditions => ['state = ?', :completed]
  named_scope :processed, :conditions => [ 'bookings.source = ? or (bookings.source != ? and bookings.transferred_at is not null)',
                                           'offline', 'offline' ]
  named_scope :confirmed, :conditions => ['state not in (?)', ['waiting', 'expired', 'overdue', 'cancelled']]
  named_scope :near_confirmed, :conditions => ['state = ? or (state in (?) and transferred_at is not null)', 'completed', [ 'place_confirmed', 'paid' ]]
  named_scope :near_confirmed_with_overdue, :conditions => ['state = ? or (state in (?) and transferred_at is not null) or state = ?', 'completed', [ 'place_confirmed', 'paid' ], 'overdue']
  named_scope :utm_source, lambda { |utm_source| { :conditions => ['utm_source = ?', utm_source] }}
  named_scope :for_date, lambda { |date| { :conditions => ['booking_date = ?', date] }}
  named_scope :from_date, lambda { |date| { :conditions => ['booking_date >= ?', date] }}
  named_scope :before_date, lambda { |date| { :conditions => ['booking_date < ?', date] }}
  named_scope :by_phone, lambda { |phone| { :conditions => ['phone = ?', phone] }}
  named_scope :by_phones, lambda { |phones| { :conditions => ['phone in (?)', phones] }}
  named_scope :created_recently, :conditions => ['created_at > ?', 1.day.ago]
  named_scope :created_between, lambda { |t1, t2| { :conditions => ['bookings.created_at >= ? and bookings.created_at < ?', t1.utc, t2.utc] }}
  named_scope :time_between, lambda {|t1, t2| { :conditions => ['time >= ? and time < ?', t1.to_time.utc, t2.to_time.utc] }}
  named_scope :created_before, lambda { |t| { :conditions => ['created_at < ?', t.utc] }}
  named_scope :created_after, lambda { |t| { :conditions => ['created_at >= ?', t.utc] }}
  named_scope :source, lambda { |source| { :conditions => ['source = ?', source] } }
  named_scope :widget, lambda { |widget| { :conditions => ['widget = ?', widget] } }
  named_scope :real_partners, lambda { { :conditions => ['bookings.source_kind = ?', 'real'] } }
  named_scope :dev_partners, lambda { { :conditions => ['bookings.source_kind = ?', 'dev'] } }
  named_scope :from_sources, lambda { |sources| { :conditions => ['bookings.source in (?)', sources] } }
  named_scope :from_phone_sources, lambda { { :conditions => ['bookings.source in (?)', Partner.phone_sources] } }
  named_scope :without_user, :conditions => 'user_id is null'
  named_scope :with_email, :conditions => 'email is not null'
  named_scope :transferred, :conditions => 'transferred_at is not null'
  named_scope :untransferred, :conditions => 'transferred_at is null'
  named_scope :without_action, :conditions => ['action = ?', 'no']
  named_scope :mark_to_cancelled, :conditions => ['action = ?', 'set_cancelled']
  named_scope :earlier, :order => 'time asc'
  named_scope :sorted, :order => 'time desc'
  named_scope :place, lambda {|place| { :conditions => ['place_id = ?', place.to_i] }}
  named_scope :yandex_book, lambda {|ya_book| { :conditions => ['yandex_book_id = ?', ya_book] }}
  named_scope :banquet, :conditions => ['bookings.banquet = ?', true]
  named_scope :not_demo_places, :joins => :place, :conditions => ['places.mode != ?', 'demo' ]
  named_scope :percent_types, :conditions => ['revenue_type in (?)', %w(price_percent bill) ]
  named_scope :organic, :conditions => ['utm_source NOT LIKE ? and utm_source not in (?) and source in (?)', '%_ppc', %w(yandex mailing phone), Partner.our_site_sources]
  named_scope :from_iphone, :conditions => ['source = ?', 'gettable-iphone']
  named_scope :mobile_without_site, lambda { { :conditions => ['source in (?)', Partner.mobile_without_site] } }
  named_scope :afisha_site, :conditions => ['source = ?', 'afisha']
  named_scope :yandex_islands, :conditions => ['source = ?', 'yandex-islands']
  named_scope :from_call_center, :conditions => ['source = ?', 'gettable-phone']
  named_scope :prime_resto, :conditions => ['source = ?', 'prime_resto']
  named_scope :resto_sites, lambda { { :conditions => ['source in (?)', Partner.resto_sources] } }
  named_scope :phone_portals, lambda { { :conditions => ['source in (?)', Partner.phone_portal_sources] } }
  named_scope :maximum_by_wday, :group => "date(bookings.created_at AT TIME ZONE 'MSK'), extract(dow from date(bookings.created_at AT TIME ZONE 'MSK'))", :order => "COUNT(*) asc"
  named_scope :without_phone_channel, :conditions => 'phone_channel is null'
  named_scope :by_phone_channels, lambda { |phone_channels| { :conditions => ['phone_channel in (?)', phone_channels] }}

  scope :our_site_sources, -> { where('source in (?)', Partner.our_site_sources) }
  scope :yandex_ppc, -> { our_site_sources.where('utm_source in (?) or utm_source ilike ?', %w(yandex_ppc spb_yandex_ppc), '%pctab_yandex_ppc%') }
  scope :mobile_yandex_ppc, -> { our_site_sources.where('utm_source ilike ?', '%mobile_yandex_ppc%') }
  scope :google_ppc, -> { our_site_sources.where('utm_source in (?) or utm_source ilike ?', %w(google_ppc spb_google_ppc), '%pctab_google_ppc%') }
  scope :mobile_google_ppc, -> { our_site_sources.where('utm_source ilike ?', '%mobile_google_ppc%') }

  scope :checked, -> { where.not(checked_at: nil, revenue_type: ['price_percent', 'monthly_pay']) }
  scope :billed, -> { where(revenue_type: 'bill') }
  scope :not_cancelled, -> { where.not(state: 'cancelled') }
  scope :revise_confirmed, -> { where.not(revise_confirmed_at: nil) }

  scope :by_phones, -> (phones) { where(phone: phones) }

  named_scope :from_google, :conditions => ['utm_source ilike ? or phone_channel in (?)', '%google_ppc%', PhoneNumber.channel_phones(:google)]
  named_scope :from_yandex, :conditions => ['utm_source ilike ? or phone_channel in (?)', '%yandex_ppc%', PhoneNumber.channel_phones(:yandex)]

  named_scope :by_city_id, lambda {|city_id|{
    :joins => :place,
    :conditions => ['places.city_id = ?', city_id]
  }}

  scope :by_place_ids, -> (ids) { where(place_id: ids) }

  named_scope :processable, lambda {{
    :joins => :place,
    :conditions => ['places.mode in (?) and bookings.source_kind = ? and ((bookings.transferred_at is null and bookings.state not in (?) and bookings.action = ?) or bookings.action != ?)', ['sms', 'ipad'], 'real', ['unconfirmed', 'waiting', 'expired'], 'no', 'no']
  }}

  named_scope :states, lambda {|*states|
    query = states.map {|it| "state = ?" }.join(' or ')
    { :conditions => states.unshift(query) }
  }

  ransacker :be_state,
    :formatter => proc { |selected_state_value|
      results = if selected_state_value == 'confirmed'
        Booking.all(:conditions => ['transferred_at is not null and bookings.state in (?)', ['paid', 'serving', 'place_confirmed']])
      else
        Booking.all(:conditions => ['bookings.state = ?', selected_state_value])
      end.map(&:id)
      # results = Order.has_pc(selected_pc_id).map(&:id)
      results = results.present? ? results : nil
    }, :splat_params => true do |parent|
    parent.table[:id]
  end

  def offline?
    source == 'offline'
  end

  def common?
    not offline?
  end

  def common_undev?
    common? and not dev_source?
  end

  # показывает на то что происходит обычный процесс букинга
  # через наш виджет(основной, мобильный или iphone app)
  # без изменения процесса букинга(как в яндексе, по телефону, оффлайн брони в iPad или для консьерж-служб)
  def common_widget?
    common? and !yandex? and !partner.by_phone?
  end

  def has_near_booking?
    has_near_active? || has_active_for_this_place?
  end

  def has_near_active?
    Booking.active.where.not(:id => id).exists?(:phone => phone, :time => (time - 1.day)..(time + 1.day))
  end

  def has_active_for_this_place?
    Booking.active.where.not(:id => id).exists?(:phone => phone, :place_id => place_id)
  end

  def kind
    offline? ? 'offline' : 'common'
  end

  def real?
    source_kind == 'real'
  end

  def with_payment?
    common? and prepayment.to_f > 0
  end

  def last_sms
    @last_sms ||= smses.without_friends.sorted.first
  end

  def consider_banquet?
    place.banquet_from && persons >= place.banquet_from && !resto_source?
  end

  def resto_source?
    partner.try(:referable_id) == place_id
  end

  def without_prepayment?
    common? and prepayment.to_f.zero?
  end

  def with_deposit?
    sum != 0
  end

  def remain_deposit
    sum.to_f - prepayment.to_f
  end

  def deposit_state
    prepayment.to_f == sum.to_f
  end

  def temporary?
    next_booking.present?
  end

  def dev_source?
    Partner.dev_sources.include? source
  end

  def night_booking?
    time.to_date != booking_date
  end

  def phone_for_sms
    night_booking? ? place.first_phone : place.city.general_phone
  end

  def close_time
    next_booking.try(:time)
  end

  def yandex?
    yandex_book_id.present?
  end

  def cancelled_from_yandex?
    cancelled_from.to_s == 'yandex'
  end

  def waiting_list?
    time_state.to_s == 'waiting_list'
  end

  def transferred?
    transferred_at.present?
  end

  def processable?
    (transferred_at.nil? &&
    !%w(unconfirmed waiting expired).include?(state) &&
    action == 'no') ||
    action != 'no'
  end

  def processed?
    transferred_at? && action == 'no'
  end

  def send_processing_sms?
    !(Settings.show_phone? or yandex?)
  end

  # state for Yandex
  def user_notified?
    paid? and !transferred? and smses_count > 0
  end

  def notify_booking_create
    if partner and partner.ext_integration?
      partner.delay.jsonrpc_create_booking(self)
    end
  end

  def notify_state_change
    if yandex?
      Island.delay.update_book_status self
    elsif partner and partner.ext_integration?
      partner.delay.jsonrpc_update_booking_state(self)
    end
  end

  def can_send_confirm_email?
    email.present? and REASONS_FOR_EMAIL_CONFIRMATION.include? confirm_reason
  end

  def finance_info_changed?
    persons_changed? or revenue_type_changed? or revenue_sum_changed?
  end

  def profile
    place.profiles.by_phone(phone.to_s).first
  end

  def partner
    @partner ||= Partner.find_by_source source
  end

  def can_destroy?
    false
  end

  def mail_sign
    Digest::SHA1.hexdigest("#{widget}_#{created_at.to_s}_GetTableMonsters")
  end

  def payer
    user
  end

  def amount
    prepayment
  end

  def revenue
    case revenue_type
    when 'table'
      revenue_sum
    when 'person'
      revenue_sum * persons
    when 'bill'
      revenue_sum
    when 'monthly_bill'
      revenue_sum
    when 'price_percent'
      "#{revenue_sum.to_f * 100}% от чека"
    when 'monthly_pay'
      "#{revenue_sum.to_i} в месяц"
    else
      0
    end
  end

  def revenue=(val)
    val = val.to_f
    if percent_type?
      set_revenue(val)
    elsif revenue != val
      set_coupon_revenue(val)
    end
  end

  def action_params
    return unless (txt = read_attribute(:action_params))

    JSON.parse(txt).with_indifferent_access
  end

  def action_params=(val)
    write_attribute(:action_params, val.to_json)
  end

  def no_actions
    no?
  end

  def estimate_revenue
    if price_percent?
      revenue_sum.to_f * (place.real_avg_price || place.avg_price) * persons
    elsif monthly_pay?
      0
    else
      revenue
    end
  end

  def total_revenue
    if place.vat? and !(price_percent? or monthly_pay?) and time >= Date.new(2013,7,1).to_time
      revenue * 1.18
    else
      revenue
    end
  end

  def set_revenue(bill_sum)
    if percent_type?
      self.revenue_sum = bill_sum
      self.revenue_type = 'bill'
    elsif monthly_pay_type?
      self.revenue_sum = bill_sum
      self.revenue_type = 'monthly_bill'
    end
  end

  def set_coupon_revenue(bill_sum)
    self.revenue_sum = bill_sum
    self.revenue_type = 'bill'
    self.coupon_revenue = true
  end

  # метод только для рассчета костов от броней на партнерских сайтах
  # для YandexDirect необходимо считать отдельно
  # для старых YaDirect кампаний можно вызывать этот метод и получим кост = 0
  # также для процентов берется оценочная выручка, основанная на ср. чеке
  def cost
    if !common_undev?
      0
    else
      if partner.cost_type == 'percent'
        estimate_revenue *  partner.cost_sum
      else
        partner.cost_sum
      end
    end
  end

  def partner_cost
    if completed?
      if partner.cost_type == 'percent'
        if price_percent?
          "#{(revenue_sum * partner.cost_sum * 100).round(2)}% от чека"
        else
          (revenue * partner.cost_sum).round(2)
        end
      else
        partner.cost_sum
      end
    end
  end

  def financial_month
    place.financial_months.for_date(booking_date).first
  end

  # надо добавить новый урл для биллинга Альфы
  def billing_url
    # booking_url url
    'https://widget.gettable.ru'
  end

  def deliver_goods!(invoice)
    return if paid?

    # помечаем, что товары по счету поставлены
    invoice.deliver

    # if user.can_receive_email?
    #   Notifier.delay.order_notification(self)
    #   Notifier.delay.gift_payment(self) if is_gift?
    # end

    self.payment_source = invoice.billing_payments.last.gateway
    pay

    # if user.payments.paid.count == 1 and user.invited_by
    #   user.inviter.reward_for! self
    # end
  end

  def create_add_to_fav_notification
    AppNotification.create do |an|
      an.kind = 'add_to_favourite'
      an.title = 'Недавно вы были в'
      an.message = place.title
      an.sub_message = 'хотите добавить его в любимые?'
      an.show_at = current_time_zone.now
      an.user = user
      an.place = place
    end
  end

  def process_started?
    operator_set_at.present?
  end

  def process_payment!(invoice, bill)
    @last_result = if payment_source == 'manual'
      "Платеж уже был активирован службой поддержки."
    elsif invoice.cancelled?
      "Платеж проведен по измененному заказу. Ваш баланс на http://gettable.ru пополнен."
    elsif paid?
      "Платеж проведен ранее. Ваш баланс на http://gettable.ru пополнен."
    elsif invoice.remaining_amount <= 0
      "Ваш платеж принят."
    else
      "Сумма не соответствует размеру платежа. Свяжитесь со службой поддержки"
    end

    Bugsnag.notify(RuntimeError.new('Booking#process_payment!'), { message: @last_result } ) if Rails.env.production?

    bill.answer = @last_result
  end

  def current_invoice(renew = false, options = {})
    unless @current_invoice
      if billing_invoices.live.last
        @current_invoice = billing_invoices.live.last

        # альфе нужен новый id для каждой попытки
        if @current_invoice.pending? && renew
          @current_invoice = @current_invoice.renew!
        end
      else
        @current_invoice = BillingInvoice.for_payable(self, options)
      end

    end
    @current_invoice
  end

  def change_place!(new_place)
    if paid?
      if new_place.call_center?
        self.place = new_place
        save
      else
        errors.add(:place, "Нельзя изменить бронь из колцентра на платформу")
      end
    else
      errors.add(:state, "Изменять место можно только paid броней")
    end
  end

  def change_table!(new_table, date = booking_date)
    old_next, old_previous = next_booking, previous_booking
    if serving? or paid?
      earlier = new_table ? new_table.next_booking(date) : nil
      if new_table and new_table.serving?(date)
        errors.add(:state, "Нельзя пересадить клиента за стол, который сейчас обслуживается")
      elsif new_table and earlier and earlier.time < time
        errors.add(:state, "Нельзя пересадить клиента за стол, на котором есть бронь раньше вашей")
      end

      unless errors.any?
        earlier.update_attribute(:previous_booking_id, id) if earlier
        self.next_booking = earlier
        self.previous_booking = nil
        self.table = new_table

        relink_bookings!(old_previous, old_next) if save
      end
    else
      errors.add(:state, "Пересаживать можно только оплаченные и обслуживаемые брони")
    end
  end

  def relink_my_bookings!
    old_next, old_previous = next_booking, previous_booking
    self.next_booking = nil
    self.previous_booking = nil
    self.save!

    relink_bookings! old_previous, old_next
  end

  def add_user_step
    if user && user.next_gift_steps
      create_user_step(user: user)
      user.send_push!('🎁 Ура! Вам начислен +1 балл!', { link: 'gettable://bonus/' })
    end
    if user && user.forwarder && user.bookings.revise_confirmed.count == 1
      create_forwarder_user_step(user: user.forwarder)
      user.send_push!('🎁 Ура! Вам начислен +1 балл!', { link: 'gettable://bonus/' })
    end
  end

  def relink_bookings!(old_previous, old_next)
    old_next.update_attribute(:previous_booking_id, old_previous.try(:id)) if old_next
    old_previous.update_attribute(:next_booking_id, old_next.try(:id)) if old_previous
  end

  def previous_performed?
    previous_booking ? previous_booking.completed? : true
  end

  def set_autocomplete
    if paid?
      if serve
        complete
        update_attribute(:autocompleted, true)
      else
        be_late
      end
    elsif place_confirmed?
      set_completed
    end
  end

  def send_notify_sms!
    send_sms!(phone, sms_notify) if transferred? and ( paid? or place_confirmed? )
  end

  def set_completed
    complete if serving? or place_confirmed?
  end

  def sms_confirmation_message
    Sms::Sms.new do |s|
      s.phone = phone
      s.message = sms_confirmation
      s.booking = self
      s.callback_method = (with_promo? ? 'promo_sms' : 'gettable_wish_sms')
    end
  end

  def with_promo?
    promo? && Promo.find_by_kind(promo).try(:sms).present?
  end

  def send_sms_gettable_wish(p_number)
    message = if partner.by_phone? || (Sms::Sms.for_phone(p_number).where('message ILIKE ?', '%gettable.ru/iphone%').count < 3 && source != 'gettable-iphone')
      "Gettable желает вам приятного отдыха! \nУправляйте бронями с вашего iPhone: gettable.ru/iphone"
    else
      "Gettable.ru желает вам приятного отдыха!"
    end
    Sms::Sms.create do |s|
      s.phone = p_number
      s.message = message
      s.booking = self
    end
  end

  def send_sms_promo(p_number)
    Sms::Sms.create do |s|
      s.phone = p_number
      s.message = Promo.find_by_kind(promo).sms
      s.booking = self
    end
  end

  def confirm_and_transfer
    confirm

    # для dev партнеров автоматически
    # перемещаем бронь в айпад а для колцентра
    # помечаем как подтвержденную
    if dev_source?
      update_attribute(:transferred_at, current_time_zone.now)
      update_attribute(:confirm_reason, '1')

      if place.platform?
        delay.send_push!
      else
        place_confirm
      end

      # send confirmation sms
      d = sms_confirmation_message
      d.save
    end
  end

  def set_expire
    expire if waiting?
  end

  def time_for_autocomplete_task
    place.close_time(booking_date)
  end

  def time_for_notify_task
    time - notify_me.minutes
  end

  def generate_url
    Digest::SHA1.hexdigest "#{id}_#{place_id}_#{place.created_at.to_s}_#{current_time_zone.now.to_s}"
  end

  def authorized_for? hash
    if hash[:action]
      if hash[:action] == 'nested'
        case hash[:link]
          when 'pre_order' then false
          else true
        end
      else
        case hash[:action]
          when 'edit' then false
          when 'show' then true
          when 'delete' then false
          when 'start_serving' then can_serve? and booking_date == place.get_booking_date
          when 'complete' then can_complete? and booking_date == place.get_booking_date
          when 'cancel' then can_cancel?
          when 'place_confirm' then can_place_confirm?
          else true
        end
      end
    else
      true
    end
  end

  def send_push!
    push = PushJob.new push_message
    push.delay.perform place.api_user
  end

  def send_cancel_sms
    sms = Sms::Sms.new do |s|
      s.phone = phone
      s.message = cancellation_text
      s.booking = self
    end

    if not sms.save
      errors.add :state, sms.errors.full_messages.join(', ')
    elsif sms.with_errors?
      errors.add :state, "Возникли ошибки при отправке рассылки. Попробуйте позже"
    end
  end

  def cancel_by!(source_name)
    return false if cancelled?
    self.cancelled_from = source_name
    self.transferred_at = current_time_zone.now unless transferred?

    if process_started?
      mark_to_set_cancelled
    else
      self.transferred_at = current_time_zone.now
      self.cancellation_text = default_cancel_reason['sms']
      cancel
      delay.send_sms!(Settings.callcenter_sms_phones.join(';'), sms_autocancel_notify)
    end
  end

  def request_change_details(action_params)
    return false if cancelled?
    self.action_params = action_params

    mark_to_change_details
  end

  def change_details!
    action_complete
  end

  def revise_confirm!
    if revise_confirmed_at.nil?
      update_attribute(:revise_confirmed_at, Time.zone.now)
      add_user_step
    end
  end

  def revise_confirmed?
    revise_confirmed_at.present?
  end

# CHECK Bottom methods and transfer them into the right place

  def send_confirmation(opts)
    if opts[:text]
      self.confirmation_text = opts[:text]
      self.confirm_reason = opts[:reason]
      self.employee_id = opts[:employee_id]
    end

    update_employee_attributes(opts)

    self.transferred_at = current_time_zone.now

    if place.platform?
      save
      delay.send_push!
    elsif action == 'no' && !place_confirm
      errors[:base] << 'Ошибка: подтвердить можно только активную бронь'
    end

    change_details! if action == 'change_details'

    unless errors.any?
      sms = sms_confirmation_message

      if can_send_confirm_email?
        Notifier.delay.booking(email, self)
      end

      if not sms.save
        errors[:base] <<  sms.errors.full_messages.join(', ')
      elsif sms.with_errors?
        errors[:base] << "Возникли ошибки при отправке рассылки. Попробуйте позже"
      else
        friend_notifications.each{ |fn| fn.create_confirmation_sms }
      end
    end
  end

  def send_cancellation(opts)
    self.transferred_at = current_time_zone.now
    self.employee_id = opts[:employee_id]

    update_employee_attributes(opts)

    if overdue?
      save
    else
      if opts[:reason] && opts[:text]
        self.cancel_reason = opts[:reason]
        self.cancellation_text = opts[:text]
      end

      if cancel
        self.__elasticsearch__.update_document if Booking.respond_to?('__elasticsearch__')
      else
        errors[:base] << 'Ошибка: отменить можно только активную бронь'
      end

    end

  end

  def send_information(opts)
    if opts[:text]
      sms = smses.build(phone: phone, message: opts[:text])

      update_employee_attributes(opts)

      if not sms.save
        errors[:base] << sms.errors.full_messages.join(', ')
      elsif sms.with_errors?
        errors[:base] << "Возникли ошибки при отправке рассылки. Попробуйте позже"
      end
    else
      errors[:base] << "Нельзя отправить пустое сообщение"
    end
  end

  def set_nonattendance
    if completed?
      set_fake
    elsif place_confirmed?
      cancel
    else
      errors[:base] << 'Бронь должна быть для колцентра'
    end
  end

  def set_deletion
    if completed?
      set_fake
    elsif place_confirmed?
      cancel
    else
      errors[:base] << 'Бронь должна быть для колцентра'
    end
  end

  def update_employee_attributes(opts)
    if opts[:employee_position]
      employee.position = opts[:employee_position]
    end

    if opts[:employee_full_position]
      employee.full_position = opts[:employee_full_position]
    end

    if opts[:employee_attributes]
      build_employee(opts[:employee_attributes].merge(:place_id => place_id))
    end
  end

  def time_tracks
    base_time = created_at
    tracks = []
    tracks << Hash[:event => 'Создана бронь',
                :time => "#{(created_at - base_time).round} сек" ]

    if operator_set_at
      t = (operator_set_at - base_time).round

      tracks << Hash[:event => 'Начал обработку',
                  :time => t > 100 ? "#{(t / 60)} мин." : "#{t} сек" ]
    end

    if smses_count > 0
      smses.all(:order => 'created_at asc').each do |d|
        t = (d.created_at - base_time).round

        tracks << Hash[:event => 'Отправлена СМС',
                    :time => t > 100 ? "#{(t / 60)} мин." : "#{t} сек",
                    :comment => d.message ]
      end
    end

    if transferred_at
      t = (transferred_at - base_time).round

      tracks << Hash[:event => 'Бронь обработана',
                  :time => t > 100 ? "#{(t / 60)} мин." : "#{t} сек" ]
    end
    tracks
  end

  def predefine_user
    if user.nil? and common_undev?
      user = User.find_by_phone phone
      self.user = user if user.present?
    end
  end

  def change_revenue_info
    if consider_banquet?
      self.banquet = true
      if revenue_type != 'bill'
        self.revenue_sum = place.banquet_percent
        self.revenue_type = 'price_percent'
      end
    else
      self.banquet = false
      self.revenue_sum = resto_source? ? partner.revenue : place.revenue
      self.revenue_type = resto_source? ? partner.revenue_type : place.revenue_type
    end
  end

  # Подготавливаю данные для elasticsearch
  def es_revenue
    (rev = revenue) && rev.is_a?(Numeric) ? rev : 0
  end

  def es_estimate_revenue
    (es_rev = estimate_revenue) && es_rev.is_a?(Numeric) ? es_rev : 0
  end

  def es_total_revenue
    (es_total_rev = total_revenue) && es_total_rev.is_a?(Numeric) ? es_total_rev : 0
  end

  class << self

    def search text
      cond = []
      [:phone, :name].each do |field|
        cond << ["bookings.#{field} ILIKE ?", "%#{text}%"]
      end

      result = [ cond.map { |q, p| q }.join(' OR ') ]
      cond.map { |q, p| result << p }

      scoped :conditions => result.flatten
    end

    def group_bookings
      real_partners \
        .where(:state => ['completed', 'overdue']) \
        .where('bookings.banquet = ? or (bookings.revenue_type in (?) AND bookings.persons >= ? )', true, %w(price_percent bill), 15) \
        .where('bookings.time < ?', Date.tomorrow.to_time) \
        .where('bookings.time > ?', Date.today.beginning_of_month.to_time.utc)
    end

    def notify_all_having_phone(phone)
      processable.where(phone: phone).find_each do |b|
        BookingPusher.new(b, 'callCenterBooking')
      end
    end
    # TODO probably should go with DelayedJob
    # handle_asynchronously :notify_all_having_phone

  end

  def current_time_zone
    Time.zone = place.try(:city).try(:time_zone) || 'Europe/Moscow'
    Time.zone
  end

  def hold_gift_item
    GiftItem.find(active_gift_item.id).update(hold: true) if active_gift_item
  end

  def set_gift_item_used_at
    GiftItem.find(gift_item.id).update(used_at: Time.now) if gift_item
  end

  def unhold_gift_item
    GiftItem.find(gift_item.id).update(hold: false) if gift_item
  end

  def reconciliation_employee_name
    reconciliation_employee.try(:name_with_position) || booking_revise_employee
  end

  def booking_revise_employee
    if br = booking_revise
      employee = br.sum_employee || br.final_employee
      employee.try(:name_with_position)
    end
  end

private

  def set_defaults
    self.place_id = table.try(:place_id) if place_id.nil?
    self.booking_date = place.get_booking_date(time) if time
    self.original_time = time
    self.url = generate_url
    self.initial_place_id = place_id
    self.email = user.email if email.blank? && user.present?
    self.room_title = 'any' unless room_title
    self.time_state = 'active' unless time_state

    # fix because of default source == bardeposit,
    # source_kind == real, but utm is null by default
    self.utm_source = 'site' if (source == 'bardeposit') && utm_source.nil?

    normalize_phone!

    # надеюсь это не сломает ничего у платформ :)
    if place.platform? && table_id.nil?
      self.table_id = place.available_or_any_table(booking_date).try(:id)
    end

    if room_id.nil? and table.try(:room_id)
      self.room_id = table.room_id
    end

    if place.platform? and offline?
      self.next_booking = table.next_booking(booking_date)
    end

    unless temporary?
      if place.platform?
        self.sum = table.sum(persons, booking_date) unless (offline? and sum.present?)
      else
        self.sum = 0.0
      end
    end

    if common?
      self.prepayment = place.prepayment_percent(sum) * sum
    else
      self.prepayment = 0 if prepayment.blank?
    end

    if fast && user
      self.phone = user.phone
      self.name = user.name
    end

  end

  def assign_stats_to_user
    if user && partner && partner.our_mobile_app?
      user.update(first_app_booking_time: created_at) unless user.first_app_booking_time
    end
  end

  def change_booking_date
    self.booking_date = place.get_booking_date(time) if time and place
  end

  def run_expire_task
    delay({:run_at => current_time_zone.now + 20.minutes}).set_expire
  end

  def change_autocomplete_task
    task = Delayed::Job.find_by_id autocomplete_task
    task.update_attribute(:run_at, time_for_autocomplete_task) if task
  end

  def change_notify_task
    task = Delayed::Job.find_by_id notify_task
    task.update_attribute(:run_at, time_for_notify_task) if task
  end

  def change_source_kind_and_utm
    if common? && utm_source.nil?
      self.utm_source = partner.try(:utm_source)
    end

    self.source_kind = if offline?
      'offline'
    elsif dev_source?
      'dev'
    else
      'real'
    end
  end

  def set_source
    self.source = Partner.source_by_channel(phone_channel)
  end

  def change_profile
    if profile
      profile.update_attribute(:name, name) if profile.name.nil? and name
      profile.update_attribute(:user_id, user_id) if profile.user_id.nil? and user_id
    elsif phone
      Profile.create do |p|
        p.place = place
        p.phone = phone
        p.name = name
        p.user = user
      end
    end
  end

  def change_phone_number
    if phone_number
      phone_number.update_attribute(:name, name) if phone_number.name.nil? and name
      phone_number.update_attribute(:user_id, user_id) if phone_number.user_id.nil? and user_id
      if phone_number.first_online_booking.nil? and common?
        assign_marketing_data(phone_number)
      end
    elsif phone
      pn = PhoneNumber.create do |p|
        p.phone = phone
        p.name = name
        p.user = user
        p.bookings_count = 1
      end

      assign_marketing_data(pn) if common?
    end
  end

  def assign_marketing_data(pn)
    pn.utm_source = utm_source
    pn.utm_content = utm_content
    pn.utm_campaign = utm_campaign
    pn.first_online_booking = created_at

    pn.save
  end

  def update_next_booking
    next_booking.update_attribute(:previous_booking_id, id)
  end

  def phone_number_confirmed
    confirmation = if partner.phone? or partner.iphone_app?
      Sms::BookingConfirmation.phone(phone).mobile_confirmed.sorted.first
    else
      Sms::BookingConfirmation.phone(phone).live(widget).sorted.first
    end

    if confirmation.nil? or !confirmation.confirmed?
      errors.add(:phone, 'Номер телефона не подтвержден')
    end

  end

  def ensure_single_booking_by_table
    if table.bookings.states('waiting').for_date(booking_date).count > 0
      errors.add(:next_booking_id, "Столик уже занят")
    elsif table.bookings.states('serving').for_date(booking_date).count > 0
      errors.add(:next_booking_id, "Столик сейчас обслуживается")
    elsif table.bookings.states('paid').for_date(booking_date).count > 0
      if next_booking_id != table.bookings.states('paid').for_date(booking_date).earlier.first.try(:id)
        errors.add(:next_booking_id, "Столик уже занят")
      end
    end
  end

  def time_into_timetable
    booking_limits = place.booking_period(booking_date)
    if time < booking_limits.first or time > booking_limits.last
      errors.add(:time, "Время брони должно соответствовать расписанию")
    end
  end

  def time_in_future
    if time < current_time_zone.now
      errors.add(:time, "Нельзя создавать бронь на прошедшее время")
    end
  end

  def prepayment_fewer_deposit
    errors.add(:prepayment, "Предоплата не может быть больше депозита") if prepayment.to_f > sum.to_f
  end

  def next_is_valid
    if next_booking.time <= time
      errors.add(:next_booking_id, "Последующая бронь должна быть позже предыдущей ")
    elsif next_booking.table_id != table_id
      errors.add(:next_booking_id, "Последующая бронь должна быть на тот же стол")
    elsif next_booking.booking_date != booking_date
      errors.add(:next_booking_id, "Последующая бронь должна быть на тот же день")
    end
  end

  def previous_is_valid
    if previous_booking.time >= time
      errors.add(:previous_booking_id, "Предыдущая бронь должна быть раньше последующей")
    elsif previous_booking.table_id != table_id
      errors.add(:previous_booking_id, "Предыдущая бронь должна быть на тот же стол")
    elsif previous_booking.booking_date != booking_date
      errors.add(:previous_booking_id, "Предыдущая бронь должна быть на тот же день")
    end
  end

  def notify_call_center
    BookingPusher.new(self, 'callCenterBooking')
  end

  def notify_call_center_on_create
    Booking.notify_all_having_phone(phone)
  end

  def update_fin_month
    financial_month.recount_sums!
  end

  def reset_operator
    self.operator_id = operator_id_was if operator_id_was
  end

  def set_operator_set_at
    self.operator_set_at = current_time_zone.now if operator_set_at.nil?
  end

  def check_gift_by_promo
    if active_gift_item

      if active_gift_item.expired_in(time)
        errors.add(:place_promo_code, "Промо код действителен до #{active_gift_item.expiry_at.strftime('%d.%m.%Y')}")
      end

    else
      errors.add(:place_promo_code, 'Промо код неверный')
    end
  end

  def gift_items
    if place_promo_code?
      GiftItem.joins(:gift).where(code: place_promo_code, gifts: { place_id: place_id })
    end
  end

  def gift_item
    gift_items.first
  end

  def active_gift_item
    gift_items.active.first
  end

end
