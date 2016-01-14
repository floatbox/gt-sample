require "open-uri"

class User < ActiveRecord::Base
  extend Enumerize
  include PhoneNormalizer
  include UserPresenter

  Genders =  { nil => 'Пол не указан', 1 => 'Парень', 2 => 'Девушка' }
  Genders_noun = { 'мужчины' => 1, 'женщины' => 2, 'не указано' => nil }

  NULL_ATTRS = %w(email phone first_name last_name address longitude latitude gender)
  EMAIL_REGEXP = /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i
  FAKE_NAMES = %w(Ефросинья Фёкла Серафима Октябрина)
  FAKE_NAME = 'Без имени'
  FAKE_AVATARS = %w(fish_bone)

  RECONCILIATION_RESPONSIBLE_IDS = [266, 26862, 90616]
  PAYMENT_RESPONSIBLE_IDS = [258]
  REFERRAL_BASE = 77475642

  devise :rememberable, :validatable, :database_authenticatable, :recoverable, :trackable,
         :lockable, :autosigninable, :encryptable, :encryptor => :old_sha1


  attr_accessible :email, :first_name, :last_name, :birthdate, :city_id, :address, :longitude, :latitude, :gender,
                  :source, :utm_medium, :utm_term, :utm_content, :utm_campaign, :password, :password_confirmation,
                  :reset_password_token, :avatar, :remember_me,  :asterisk_agents_updated_at, :asterisk_agents

  enumerize :role, :in => %w(loyalty_manager account_manager account_manager_extended
    site_admin call_center call_intern sale sale_manager seo partner head_of_sales
    head_of_call widget content_manager place_revisor guest_revisor), :scope => true

  belongs_to :forwarder, class_name: 'User', foreign_key: :forwarder_id, inverse_of: :forwarder
  has_many :referrals, class_name: 'User', foreign_key: :forwarder_id, inverse_of: :referrals
  has_many :user_contacts

  belongs_to :city
  belongs_to :partner
  belongs_to :mobile_avatar, class_name: 'Avatar', foreign_key: :avatar_id

  has_many :account_confirmations, :class_name => 'Sms::AccountConfirmation'
  has_many :bookings
  has_many :orders, class_name: 'Booking', foreign_key: :operator_id
  has_many :initial_orders, class_name: 'Booking', foreign_key: :initial_operator_id
  has_many :external_users
  has_many :tokens, :as => :item
  has_many :favourite_places
  has_many :friend_notifications
  has_many :places, :through => :favourite_places
  has_many :user_activities
  has_many :app_notifications
  has_many :contracts, foreign_key: :sale_id
  has_many :reconciliations, foreign_key: :verify_by
  has_many :place_selections, foreign_key: :operator_id
  has_many :call_records, foreign_key: :operator_id
  has_many :referrals, class_name: 'User', foreign_key: :forwarder_id
  has_many :answers
  has_many :answer_likes
  has_many :gift_items
  has_many :steps, class_name: 'UserStep'
  has_many :referrals_places, -> { uniq }, through: :referrals, source: :places
  has_many :user_avatars
  has_many :place_booking_revises, class_name: 'BookingRevise', foreign_key: :place_responsible_id
  has_many :guest_booking_revises, class_name: 'BookingRevise', foreign_key: :guest_responsible_id
  has_many :final_booking_revises, class_name: 'BookingRevise', foreign_key: :final_responsible_id
  has_many :sum_booking_revises, class_name: 'BookingRevise', foreign_key: :sum_responsible_id

  has_attached_file :avatar, { styles: { flow: ['50x50#', 'jpg'],
                                         small: ['30x30#', 'jpg'],
                                         profile: ['100x100#', 'jpg'],
                                         iphone_profile: ['88x88#', 'jpg'],
                                         iphone_profile_2x: ['176x176#', 'jpg'],
                                         iphone_profile_3x: ['264x264#', 'jpg'],
                                         iphone_review: ['40x40#', 'jpg'],
                                         iphone_review_2x: ['80x80#', 'jpg'],
                                         iphone_review_3x: ['120x120#', 'jpg'] },
                               path: "users/:id/avatar_:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  process_in_background :avatar

  before_validation_on_create :set_defaults!
  before_validation :nil_if_blank
  before_validation :normalize_phone!, :if => lambda{ |u| u.phone && u.phone_changed? }

  validates :city_id, :source, presence: true
  validates :phone, :sale_contract_prefix, :vkontakte_uid, :odnoklassniki_uid, :facebook_uid,
            :twitter_uid, :iphone_udid, :email, uniqueness: true, allow_blank: true
  validate_on_create :phone_number_confirmed, :if => lambda{ |u| u.phone && u.phone_changed? }
  validate_on_update :phone_confirmed_for_user, :if => lambda{ |u| u.phone && u.phone_changed? }
  validate :udid_without_phone
  validate :forwarder_exist, on: :update, :if => lambda{ |u| u.forwarder_id && u.forwarder_id_changed? }

  validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\Z/, allow_blank: true

  before_validation :check_email_uniqueness

  after_create :send_registration_mail, :if => lambda{ |u| u.email && u.role }

  before_save  :set_asterisk_agents_updated_at, :if => lambda{ |u| u.asterisk_agents? && u.asterisk_agents_changed? }
  after_save   :assign_bookings, :if => lambda{ |u| u.phone && u.phone_changed? }
  after_save   :write_activity, :if => lambda{ |u| u.on_duty_changed? }
  after_save   :asterisk_line_cleared, :if => lambda{ |u| u.asterisk_agents_changed? && u.asterisk_agents.blank? }

  named_scope :sale, :conditions => ['role = ?', 'sale']
  named_scope :head_of_sales, :conditions => ['role = ?', 'head_of_sales']
  named_scope :by_phone, lambda { |phone|
    { :conditions => ['phone = ?', normalized_phone(phone)] }
  }

  named_scope :now_on_duty, :conditions => 'on_duty = true'
  named_scope :with_bookings, :joins => :bookings, :conditions => ['bookings.state IN (?)', %w(unconfirmed overdue paid serving cancelled waiting place_confirmed)]

  named_scope :on_place, lambda { |place| { :joins => :bookings, :conditions => ['bookings.place_id = ?', place ] } }
  named_scope :call_center_section, :conditions => [ 'users.role IN (?)', ['call_center', 'head_of_call', 'call_intern']]
  named_scope :sales_section, :conditions => [ 'users.role IN (?)', ['sale', 'head_of_sales']], :order => 'first_name asc'
  named_scope :managers, :conditions => [ 'users.role IN (?)', ['account_manager', 'account_manager_extended']], :order => 'first_name asc'
  named_scope :head_of_sales_extended, :conditions => [ 'users.role IN (?)', ['head_of_sales', 'account_manager_extended']], :order => 'first_name asc'
  scope :not_fired, -> { where(fired_at: nil) }
  scope :first_app_booking_between, ->(t1, t2) { where('first_app_booking_time >= ? AND first_app_booking_time < ?', t1.utc, t2.utc) }
  scope :created_between, ->(t1, t2) { where('users.created_at >= ? and users.created_at < ?', t1.utc, t2.utc) }
  scope :revise_managers, -> { where(role: %w(account_manager account_manager_extended place_revisor guest_revisor)) }

  # Attributes

  def self.call_center_employees
    Rails.env.test? ? [] : call_center_section
  end

  def age
    begin ((Time.now - birthdate.to_time).to_f/(60*60*24)/365.2422).to_i rescue 0 end
  end

  def avatar_from_url(url)
    self.avatar = open(url)
  end

  def remember_me
    true
  end

  def fake_avatar
    FAKE_AVATARS[id % FAKE_AVATARS.size]
  end

  def fake_name
    ''
  end

  def send_push!(message, custom_data = nil)
    tokens.each do |token|
      notification = Houston::Notification.new(device: token.device_token)
      notification.alert = message
      notification.custom_data = custom_data if custom_data
      APN.push(notification)
    end
  end

  def name(default = nil)
    default ||= filtered_email
    first_name.blank? ? default : first_name
  end

  def name=(val)
    self.first_name = val
  end

  def forwarder_code
    (REFERRAL_BASE + id).to_s(36)
  end

  def forwarder_code=(val)
    self.forwarder_id = val.to_i(36) - REFERRAL_BASE
  end

  def referrals_places
    referrals.collect{|u| u.places}.flatten.uniq
  end

  def contacts_places
    phones = user_contacts.phones.pluck(:value)
    bookings = Booking.by_phones(phones).select('place_id, COUNT(DISTINCT(phone)) AS counter').group(:place_id).to_sql
    Place.production.select('uc_places.counter AS user_counter, places.*').joins('INNER JOIN (' + bookings + ') uc_places ON places.id = uc_places.place_id').order('uc_places.counter DESC')
  end

  def my_contracts
    if sale_ability_can? :manage, :all_contracts
      Contract.all
    else
      contracts
    end
  end

  def my_call_records
    if records_ability_can? :manage, :all_call_records
      CallRecord.all
    elsif records_ability_can? :read, :finance_call_records
      CallRecord.only_finantial
    else
      call_records
    end
  end

  def sale_ability
    @sale_ability ||= Ability::Sale.new(self)
  end
  delegate :can?, :cannot?, :to => :sale_ability, :prefix => true

  def records_ability
    @records_ability ||= Ability::Records.new(self)
  end
  delegate :can?, :cannot?, :to => :records_ability, :prefix => true

  # возвращает входящий звонок от клиента, который на линии в данный момент
  def incoming_on_line_record
    if (cr = call_records.sorted.first) && cr.incoming? && cr.on_line?
      cr
    end
  end

  # возвращает массив входящих звонков от клиента, который на линии в данный момент
  def incoming_online_records
    call_records.online
  end

  # Shortcuts

  def phone_code
    city.country.phone_code
  end

  def photo(style)
    self.avatar? ? avatar.url(style) : default_gender_photo(style)
  end

  # Predicates

  def woman?
    gender == 2
  end

  def man?
    gender == 1
  end

  def partner?
    role == 'partner'
  end

  def okl_user?
    odnoklassniki_uid.present?
  end

  def vk_user?
    vkontakte_uid.present?
  end

  def fb_user?
    facebook_uid.present?
  end

  def twi_user?
    twitter_uid.present?
  end

  def located?
    latitude.present? && longitude.present?
  end

  def unlocated?
    !located?
  end

  def skip_email_validation?
    (okl_user? or vk_user? or fb_user? or twi_user? or iphone_udid or phone) && email.nil?
  end

  def developer?
    [33, 34].include? id
  end

  def callcenter_sms_on?
    phone and Settings.callcenter_sms_phones.include?(phone)
  end

  def image_changed?
    avatar_file_size_changed? ||
    avatar_file_name_changed? ||
    avatar_content_type_changed? ||
    avatar_updated_at_changed?
  end

  # Callbacks

  def write_activity
    on_duty ? user_activities.create( :started_at => Time.now ) : user_activities.last.update( :ended_at => Time.now )
  end

  def handle!(object)
    transaction do
      lock!
      yield
      save!
    end
  end

  def hand_over_bookings_to(acceptor)
    bookings.find_each{ |b| b.update_attributes(:user_id => acceptor.id); }
  end

  def hand_over_places_to(acceptor)
    favourite_places.find_each{ |fp| fp.update_attributes(:user_id => acceptor.id); }
  end

  def make_step(attributes = nil)
    steps.create(attributes)
  end

  def steps_sum
    steps.sum(:amount)
  end

  def regenerate_styles!
    self.avatar.reprocess!
    self.processing = false
    self.save(validate: false)
  end

  # Other methods

  def generate_password(length = 8)
    c = %w{b c d f g h j k l m n p qu r s t v w x z ch cr fr nd ng nk nt ph pr
           rd sh sl sp st th tr}
    v = %w{a e i o u y}
    (1..(length / 2)).map { c.sample + v.sample }.join[0..length]
  end

  def reset_phoneline
    if asterisk_agents_updated_at && asterisk_agents_updated_at < 12.hours.ago
      update_attributes(:asterisk_agents => '', :asterisk_agents_updated_at => nil)
    end
  end

  def set_mobile_avatar(avatar)
    update_attributes(avatar_id: avatar.id)
  end

private

  def set_defaults!
    self.city_id ||= 1
    self.source ||= 'site'
    password = generate_password
    self.password = password
    self.password_confirmation = password
    self.email = email.downcase if email
  end

  def send_registration_mail
    Notifier.delay.registration_mail(self, password)
  end

  def nil_if_blank
    self.password = nil if password.blank? # password is virtual attr
    NULL_ATTRS.each { |attr| self[attr] = nil if self[attr].blank? }
  end

  def phone_number_confirmed
    unless Sms::AccountConfirmation.live.confirmed.phone(phone).sorted.first
      errors.add(:phone, 'Номер телефона не подтвержден')
    end
  end

  def phone_confirmed_for_user
    unless account_confirmations.live.confirmed.phone(phone).sorted.first
      errors.add(:phone, 'Номер телефона не подтвержден')
    end
  end

  def udid_without_phone
    errors.add(:phone, 'Нельзя чтобы одновременно был udid и номер телефона') if iphone_udid and phone
  end

  def forwarder_exist
    errors.add(:forwarder_code, 'Промокод не верен') unless User.find_by(id: forwarder_id).present?
  end

  def assign_bookings
    Booking.by_phone(phone).find_each{ |b| b.update_attribute(:user, self) }
  end

  def check_email_uniqueness
    self.email = email_was if User.exists?(:email => email)
  end

  def set_asterisk_agents_updated_at
    self.asterisk_agents_updated_at = Time.zone.now
  end

  def asterisk_line_cleared
    LineClearedPusher.new(self, 'lineCleared')
  end

  def self.users_steps_qnt(city_id)
    if city_id
      city_condition = sanitize_sql_array([ "where users.city_id = %s", city_id ])
    else
      city_condition = ''
    end
    sql_query =
      "select (next_gift_steps - steps_qnt) as diff, count(user_id) as users_qnt from
      (
        select sum(amount) as steps_qnt, user_id, next_gift_steps from user_steps
          join users on users.id = user_steps.user_id
          #{city_condition}
          group by user_id, next_gift_steps
      )
      as users_by_steps_qnt
        group by diff
        order by diff"
    ActiveRecord::Base.connection.execute(sql_query)
  end

  def self.user_gifts_qnt( options = {} )
    qnt = options[:qnt] || 0
    if options[:city_id]
      city_condition = sanitize_sql_array([ "where users.city_id = %s", options[:city_id] ])
    else
      city_condition = ''
    end
    if qnt == 0
      sql_query =
        "select diff, count(user_id) from
        (
          select next_gift_steps - sum(amount) as diff, user_id, next_gift_steps from user_steps
            join users on users.id = user_steps.user_id
            #{city_condition}
            group by user_id, next_gift_steps
        )
        as users_by_steps_qnt
          where user_id not in ( select user_id from gift_items where user_id is not null )
          group by diff
          order by diff;"
    else
      sql_query = sanitize_sql_array([
        "select diff, count(qnt) from
        (
          select diff, count(gift_items.user_id) as qnt from
          (
            select next_gift_steps - sum(amount) as diff, user_id from user_steps
              join users on users.id = user_steps.user_id
              #{city_condition}
              group by user_id, next_gift_steps
          )
          as user_diffs
            join gift_items on user_diffs.user_id = gift_items.user_id
            group by diff, gift_items.user_id
            having count(gift_items.user_id) = %s
        )
        as gifts_qnt
          group by diff", qnt ])
    end
    ActiveRecord::Base.connection.execute(sql_query).values
  end

end
