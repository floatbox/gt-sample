class Place < ActiveRecord::Base
  # mode - тип подключения заведения, напр. ipad, demo, sms - бронь через колцентр
  # votes - количество позитивных отзывов

  reverse_geocoded_by :latitude, :longitude
  include PaymentLogic, PhoneNormalizer, PlacePresenter, PlaceElasticSearch,
    ActionController::UrlWriter, UrlHelper, ActsAsObservable, ActsAsBooleanTime

  extend Enumerize, ActsAsXlsx, RansackerDummy

  acts_as_xlsx unless Rails.env.test?
  acts_as_boolean_time :initial_call_at
  acts_as_observable :fields => %w(revenue revenue_type agent_id contract_id vat permalink comment)

  MODES = %w( ipad demo sms )
  CATEGORIES = %w( restaurant cafe bar club )
  PLACE_LINKS = %w( site_url facebook_url vk_url twitter_url foursquare_url instagram_url )
  CONTEXT_RATES = %w( top medium low )
  BANQUET_FIELDS = %w( banquet_rooms_description banquet_karaoke banquet_alco banquet_music banquet_dancefloor banquet_comment working_new_years_night )
  LANDING_FIELDS = %w( title address avg_price preferred_category afisha_description short_description metro_station_id
                       full_description meta_title meta_description our_review working_time tags visible )
  SEO_FIELDS = %w( afisha_description full_description meta_title meta_description our_review )

  ALL_ZONES = { 'any' => 'не важно',
                'smoking' => 'курящая',
                'nosmoking' => 'не курящая' }

  TEST_IDS = %w( 1 839 )

  attr_accessor :stickers
  enumerize :revenue_type, :in => PLACE_PAYMENT_KINDS
  enumerize :mode, :in => MODES, :predicates => true
  enumerize :sales_rate, :in => %w(A B C C+)
  enumerize :inability_to_pay_kind, :in => %w(weak strong)

  belongs_to :agent
  belongs_to :break_responsible, :class_name => 'User'
  belongs_to :city
  belongs_to :contract
  belongs_to :metro_station
  belongs_to :payment_responsible, :class_name => 'User'
  belongs_to :place_group
  belongs_to :previous_place, :class_name => 'Place'
  belongs_to :sale, :class_name => 'User'
  belongs_to :initial_call_responsible, :class_name => 'User'
  belongs_to :financial_check_responsible, :class_name => 'User'

  has_one :api_user
  has_one :timetable
  has_one :brief, -> { where(category: :brief) }, :class_name => 'PrivateFile', :as => :fileable

  has_many :afisha_photos
  has_many :availabilities, :through => :timetable
  has_many :bookings
  has_many :employees
  has_many :events
  has_many :external_reviews
  has_many :financial_conditions
  has_many :financial_months
  has_many :galleries
  has_many :menu_categories
  has_many :menu_items
  has_many :menu_global_categories, -> { uniq.order(:position) }, through: :menu_categories
  has_many :menu_sub_categories
  has_many :order_rooms
  has_many :place_photos
  has_many :private_files, :as => :fileable
  has_many :profiles
  has_many :quotes, dependent: :destroy
  has_many :reconciliations
  has_many :reviews
  has_many :rooms
  has_many :tables
  has_many :waitings

  has_many   :place_selection_places
  has_many   :place_selections, :through => :place_selection_places

  # Тэги нужны для описания особенностей бронирования
  has_many :tagged_items, :as => :item, :dependent => :destroy
  has_many :booking_features, :through => :tagged_items, :class_name => 'Tag', :source => :tag

  has_many :partners, :as => :referable
  has_many :direct_call_records, :class_name => 'CallRecord'

  has_many :favourite_places
  has_many :place_features, dependent: :destroy, inverse_of: :place
  has_many :features, :through => :place_features, :source => :feature, :order => 'weight desc'
  has_many :specializations, -> { where('place_features.main = true') },
                             through: :place_features, source: :feature
  has_many :specializations_landings, ->(p) { where("landings.city_id = ?", p.city_id) },
                                      class_name: "Landing",
                                      through: :specializations,
                                      source: :landings

  has_many :main_features, :through => :place_features, :source => :feature, :conditions => 'weight = 0.75'
  has_many :not_main_features, :through => :place_features, :source => :feature, :conditions => 'weight = 0.25'
  has_many :pdf_menus, inverse_of: :place
  has_many :gifts

  accepts_nested_attributes_for :agent, :contract, :quotes,
                                allow_destroy: true, reject_if: :all_blank

  has_and_belongs_to_many :promos


  has_attached_file :logo, { :styles => LOGO_STYLES,
                             :path => "bars/:id/main/logo_:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_presence_of :city
  validates_presence_of :title, :mode
  validates_presence_of :address, :phone, :avg_price, :if => :published?

  validates_uniqueness_of :permalink, :unless => :demo?

  validates_inclusion_of :mode,  :in => MODES
  validates_inclusion_of :preferred_category,  :in => CATEGORIES
  validates_inclusion_of :context_rate,  :in => CONTEXT_RATES
  validates_inclusion_of :zones, :in => ALL_ZONES.keys
  validates_inclusion_of :yandex_mode, :in => %w( no dynamic-resource-only static )

  validates_attachment_content_type :logo, :content_type => ['image/jpeg', 'image/pjpeg', 'image/jpg', 'image/png'], :allow_blank => true

  named_scope :demo, :conditions => ['mode = ?', 'demo' ]
  named_scope :not_demo, :conditions => ['mode != ?', 'demo' ]
  named_scope :ipad, :conditions => ['mode = ?', 'ipad' ]
  named_scope :prime_resto, :conditions => ['prime_resto = ?', true ]
  named_scope :sms, :conditions => ['mode = ?', 'sms' ]
  named_scope :visible, :conditions => 'visible = true'
  named_scope :financial_checked, :conditions => 'financial_checked = true'
  named_scope :created_between, lambda {|t1, t2| { :conditions => ['created_at >= ? and created_at < ?', t1.utc, t2.utc] }}
  named_scope :stopped_between, lambda {|t1, t2| { :conditions => ['stopped_at >= ? and stopped_at < ?', t1.utc, t2.utc] }}
  named_scope :yandex_active, :conditions => ['yandex_mode != ?', 'no']
  named_scope :city, lambda {|city| { :conditions => ['city_id = ?', city.to_i] }}
  named_scope :category, lambda {|category| { :conditions => ['preferred_category = ?', category] }}
  named_scope :sorted, -> { order(title: :asc) }
  named_scope :rated, :conditions => 'rate is not null'
  named_scope :financial_active, :conditions => ['fin_panel_active = ?', true]
  scope :afisha, -> { where(afisha: true) }
  scope :zoon, -> { where(zoon: true) }
  scope :timeout, -> { where(timeout: true) }
  scope :soon,  -> { where(soon: true) }
  scope :without_soon, -> { where(soon: false) }
  named_scope :without_brand_context, :conditions => ['brand_context = ?', false]
  named_scope :only_persons_payment, :conditions => ['revenue_type in (?)', PAYMENT_PERSON_KINDS]
  named_scope :prices, lambda {|prices| { :conditions => ['avg_price BETWEEN ? AND ?',
                                                           prices.min == 1000 ? 0 : prices.min,
                                                           prices.max == 3000 ? 30000 : prices.max] }}

  named_scope :break_kind, lambda {|types| { :conditions => ['break_kind in (?)', types] }}

  named_scope :with_deposits, lambda {
    deposit_params = %w( deposit_sum entrance_sum deposit_str )
    query = Timetable::WORKING_DAYS.map{|wd| deposit_params.map{ |dp| "timetables.#{wd}_#{dp} is not null" } }.flatten.join(' or ')
    { :joins => :timetable, :conditions => query }
  }

  named_scope :without_deposits, lambda {
    deposit_params = %w( deposit_sum entrance_sum deposit_str )
    query = Timetable::WORKING_DAYS.map{|wd| deposit_params.map{ |dp| "timetables.#{wd}_#{dp} is null" } }.flatten.join(' and ')
    { :joins => :timetable, :conditions => query }
  }

  %w(our_review short_description full_description meta_title meta_description prime_resto_description).each do |field|
    named_scope "with_#{field}".to_sym, :conditions => ["#{field} IS NOT NULL AND #{field} != ''"]
    named_scope "without_#{field}".to_sym, :conditions => ["#{field} IS NULL OR #{field} = ''"]
  end

  named_scope :with_menu_items, :joins => :menu_items, :select => 'places.id, places.title, COUNT(menu_items.id) as menu_items_count', :order => 'places.title', :group => 'places.id'
  named_scope :with_unchecked_menu_items, :joins => :menu_items, :select => 'places.id, places.title, COUNT(menu_items.id) as unchecked_menu_items_count', :conditions => 'menu_items.checked_at IS NULL', :group => 'places.id', :order => 'unchecked_menu_items_count DESC'
  named_scope :with_banquets, :conditions => ["banquet_updated_at IS NOT NULL"]

  scope :by_feature, -> (*f) { includes(:features).where('features.id = ?', f) }
  scope :faked, -> { where(fake: true) }
  scope :without_fake, -> { where(fake: false) }
  scope :with_events, -> { joins(:events).where('events.id IS NOT NULL') }
  scope :with_future_events, -> { joins(:events).select('places.*, events.start_at').where('events.id IS NOT NULL').where('events.start_at > ?', 1.hour.ago.utc).distinct.order('events.start_at') }

  scope :launched_between, -> (t1, t2) { where('launched_at >= ? and launched_at < ?', t1.to_time.utc, t2.to_time.utc) }
  scope :stopped_between, -> (t1, t2) { where('stopped_at >= ? and stopped_at < ?', t1.to_time.utc, t2.to_time.utc) }

  before_validation_on_create :set_defaults
  before_save :prevent_scaffold_bugs
  before_save :update_postal_coordinates, :if => lambda{ |p| p.postal_address.present? and p.postal_address_changed? }
  before_save :renew_landing_updated_at, :if => lambda{ |p| LANDING_FIELDS.map{ |f| p.send("#{f}_changed?") }.include?(true) }
  before_save :renew_banquet_updated_at, :if => lambda{ |p| BANQUET_FIELDS.map{ |f| p.send("#{f}_changed?") }.include?(true) }
  before_save :renew_seo_updated_at, :if => lambda{ |p| SEO_FIELDS.map{ |f| p.send("#{f}_changed?") }.include?(true) }
  before_save :send_break_notify, :if => lambda{ |p| p.break_notify_at.present? and p.break_notify_at_changed? }
  before_save :renew_launch_fields, :if => lambda{ |p| p.visible_changed? || p.financial_checked_changed? }
  before_save :reset_contract_id, :if => :agent_id_changed?
  after_create :create_timetable
  after_create :create_financial_months
  after_create :set_mobile_map_url

  delegate :today_working_time, :today_working_state, :today_until_working_time, :working_day?,
    :deposit_summary, :lunch_summary, :call_deposit_description, :to => :timetable
  delegate :special_description, :special_info_where,
    :to => :timetable, :prefix => true, :allow_nil => true
  delegate :name, :to => :metro_station, :prefix => true, :allow_nil => true
  delegate :title, :parent_id, :parent_title, :to => :place_group,
    :prefix => true, :allow_nil => true
  delegate :permalink, :name, :name_p,
    :to => :city, :prefix => true, :allow_nil => true

  ransacker :be_production,
    :formatter => proc { |selected_state_value|
      results = if selected_state_value
        Place.production
      else
        Place.not_demo
      end.map(&:id)

      results = results.present? ? results : nil
    }, :splat_params => true do |parent|
    parent.table[:id]
  end

  # Predicates

  def published?
    active? && !demo?
  end

  def active?
    visible && financial_checked
  end

  def demo?
    mode == 'demo'
  end

  def platform?
    mode == 'demo' or mode == 'ipad'
  end

  def call_center?
    mode == 'sms'
  end

  def with_order_rooms?
    call_center? or order_rooms.count > 0
  end

  def with_rooms?
    rooms.count > 0
  end

  def nearest_event
    events.future.sorted.first
  end

  def show_phone?
    Settings.show_phone? && active? && ( working_day? || Settings.time_referred_show_phone? )
  end

  def has_links?
    PLACE_LINKS.map{ |l| self[l].present? }.include? true
  end

  def has_employees?
    employees.count > 0
  end

  def smoking?
    zones and zones == 'smoking'
  end

  def nosmoking?
    zones and zones == 'nosmoking'
  end

  def has_1c_uids?
    contract_1c_uid.present? && agent_1c_uid.present?
  end

  def probably_will_not_work_tomorrow?
    RedisLogger.get_param("places:ringup_list")[id.to_s].to_i > 0 && Time.zone.now.hour < 21
  end

  # Associations

  def categories
    CATEGORIES.map{|cat| cat if self[cat] }.compact
  end

  def network_landings
    SiteLanding.includes(:landing_filters => :search_filter) \
      .where(landings: { city_id: city_id }) \
      .where(filters: { value: "network_#{place_group_id}" }) \
      .to_a
  end

  def report_emails
    employees.working.revise.all.map{|e| e.email.split(/,|;/).map{|s| s.strip} if e.email }.flatten.compact.uniq
  end

  def daily_report_emails
    employees.working.daily_revise.all.map{|e| e.email.split(/,|;/).map{|s| s.strip} if e.email }.flatten.compact.uniq
  end

  def invoice_emails
    employees.working.payment.all.map{|e| e.email.split(/,|;/).map{|s| s.strip} if e.email }.flatten.compact.uniq
  end

  def network_landing
    @network_landing ||= network_landings.first
  end

  def specialization_landing
    @specialization_landing ||= specializations_landings.first
  end

  def full_month_start_at
    if launch_from
      launch_from.day == 1 ? launch_from : launch_from.beginning_of_month + 1.month
    end
  end

  def full_month_count
    if full_month_start_at
      current_month = Date.today.beginning_of_month
      (current_month.year * 12 + current_month.month) - (full_month_start_at.year * 12 + full_month_start_at.month)
    else
      0
    end
  end

  def available_table(date, smoking = 'any')
    # для начала можно рандомно подбирать, но потом надо сделать стол-заявку и туда все скидывать
    it = case smoking
      when 'smoking' then tables.opened.without_deposit_on(date).smoking
      when 'nosmoking' then tables.opened.without_deposit_on(date).no_smoking
      else tables.without_deposit_on(date).opened
    end
    it.each do |t|
      if t.avaliable_on?(date)
        @res = t and break
      end
    end

    if @res.nil? and smoking != 'any'
      tables.opened.without_deposit_on(date).each do |t|
        if t.avaliable_on?(date)
          @res = t and break
        end
      end
    end

    @res
  end

  def available_or_any_table(date, smoking = 'any')
    # для случая если успели забронировать после того как
    # получили состояния столов и забрали последний подходящий
    # тогда будет выдаваться ошибка

    available_table(date, smoking) || tables.opened.first
  end

  def current_financial_month
    financial_months.for_date(1.month.ago.beginning_of_month.to_date).first
  end

  def reconcilation_act(date_from, date_to, stamp)
    data = { 'BeginPeriod' => date_from,
             'EndPeriod'   => date_to,
             'CustomerID'  => agent_1c_uid }

    AccountantServer.reconcilation_act(data, stamp)
  end

  def available_schedule(date)
    nearest_time = timetable.nearest_booking_time(date, false, 15)
    timetable.timenet_with_states(date, nearest_time, true)
  end

  def displaying_features
    features.show_in_tags
  end

  # features list without specialization
  def feature_list
    displaying_features.where('place_features.main = false').all.map{ |f| f.title }.join(', ')
  end

  def landing_subfeatures(landing_features)
    if landing_features.present?
      place_landing_features = features & landing_features
      # place_landing_features_children_ids = place_landing_features.collect(&:children).flatten.collect(&:id)
      # place_features.where(feature_id: place_landing_features_children_ids).includes(:feature)
      place_features.joins(:feature).where(features: { parent_id: place_landing_features.map(&:id) })
    end
  end

  # TODO: Depricated

  def photo_by_priority(tags)
    p = place_photos.first( :joins => :tagged_items, :conditions => ["tagged_items.tag_id in (?)", tags],
                            :order => "idx(ARRAY[#{tags * ','}], tagged_items.tag_id)") if tags.present?
    p ? p.search : main_photo.try(:search)
  end

  def similar
    Place.es_similar(similar_serialize)
  end

  def similar_available(date = nil, total = 3)
    count = 0

    similar.records.limit(20).select do |place|
      count < total && place.working_day?(date) && (count += 1)
    end
  end

  def possible_place_features
    place_features.includes(:feature) + unpersisted_place_features
  end

  def unpersisted_place_features
    Feature.where.not(kind: %w(place_group place_avg_price), id: place_features.pluck(:feature_id)).map do |feature|
      place_features.build(feature: feature)
    end
  end

  # Shortcuts

  def smart_working_time(break_str = ', ')
    if stay_text_working_date || !timetable.has_working_time?
      working_time.to_s.gsub(/, ?\<br ?\/?\>/i, break_str)
    else
      timetable.working_time(break_str)
    end
  end

  def likes
    reviews.positive.count + favourite_places.count + 5 + id % 10
  end

  def review_count
    reviews.for_public.count
  end

  def main_feature
    specializations.first
  end

  def badge_features
    features.kinds(:badge)
  end

  def main_feature_emoji
    main_feature.emoji if main_feature
  end

  def specialization
    main_feature ? main_feature.specialization : category_name('i', true)
  end

  def specialization_icon
    main_feature.try(:icon_gray_2x)
  end

  def features_description(selected_features = [])
    if selected_features.present?
      place_features.with_text.where('feature_id in (?)', selected_features.map{|sf| sf.id}).first.try(:text)
    end
  end

  def menu_cover
    specializations.with_menu_photo.first.try(:menu_photo)
  end

  def booking_period(date)
    timetable.booking_period_for_date(date)
  end

  def get_booking_date(time = Time.zone.now)
    timetable.booking_date_for_time(time)
  end

  def close_time(date)
    booking_period(date).last + Timetable::DELTA.minutes
  end

  def phone_code
    city.country.phone_code
  end

  def prepayment_percent(sum)
    financial_conditions.for_sum(sum).first.try(:percent).to_f
  end

  def stringify_avg_price
    "#{avg_price.to_i > 4000 ? 'выше 4000' : avg_price } руб."
  end

  def in_favourites?(user)
    user.favourite_places.where(place_id: id).count > 0
  end

  def description
    read_attribute(:afisha_description)
  end

  def landing_updated_at
    [ read_attribute(:landing_updated_at),
      reviews.sorted.select(:created_at).try(:first).try(:created_at),
      timetable.updated_at,
      favourite_places.sorted.select(:created_at).try(:first).try(:created_at)
    ].compact.max
  end

  def partner_reward(percent)
    k = price_percent? ? 100 : 1
    (revenue.to_f  * percent * k).round(2)
  end

  def basic_serialization
    main_feature_serialized = main_feature ? main_feature.basic_serialization : nil
    {
      id:             id,
      title:          title,
      specialization: specialization,
      likes:          likes,
      longitude:      longitude,
      latitude:       latitude,
      avg_price:      stringify_avg_price,
      mobile_list_2x: mobile_list_2x,
      mobile_list_3x: mobile_list_3x,
      main_feature:   main_feature_serialized
    }
  end

  def hours
    Timetable::WORKING_DAYS.map do |day|
      timetable.es_weekday_working_time(day)
    end.compact
  end

  def similar_serialize
    {
      :id =>       id,
      :features => place_features.map{ |pf| { :id => pf.feature_id, :weight => pf.weight } },
      :price =>    price_ranges,
      :city_id =>  city_id,
      :location => [{ :distance => 20, :location => coordinates }]
    }
  end

  def price_ranges
    case avg_price
    when 0..1499
      [{ :min => 0, :max => 1500 }]
    when 1500
      [{ :min => 0, :max => 2500 }]
    when 1501..2499
      [{ :min => 1500, :max => 2500 }]
    when 2500
      [{ :min => 1500, :max => 1000000 }]
    else
      [{ :min => 2500, :max => 1000000 }]
    end
  end

  def banquet_alco_present
    banquet_alco.present?
  end

  def banquet_music_present
    banquet_music.present?
  end

  def banquet_dancefloor_present
    banquet_dancefloor.present?
  end

  def banquet_ny_conditions_present
    ny_conditions.present?
  end

  # Attributes

  def history
    h = read_attribute(:history)
    JSON.parse(h) if h
  end

  def history=(val)
    write_attribute(:history, val.to_json)
  end

  def site_url
    read_attribute(:site_url)
  end

  def min_persons
    super || 1
  end

  def max_persons
    super || 150
  end

  # Methods

  def fetch_postal_coordinates
    result = Geocoder.coordinates postal_address
    if result.present?
      update_attributes! :postal_address_lon => result[1], :postal_address_lat => result[0]
    end
  end

  def update_postal_coordinates
    delay.fetch_postal_coordinates
  end

  def increase_votes!
    Place.transaction do
      self.lock!
      self.reload
      self.votes += 1
      self.save
    end
  end

  def distance_from(location)
    dist = Geocoder::Calculations.distance_between([longitude, latitude], location)
  end

  def change_bookings_revenue(date_from)
    date = date_from.to_time.utc

    bookings.where('time >= ?', date).find_each do |booking|

      unless booking.revenue_type == 'bill'
        booking.change_revenue_info
        booking.save
      end

    end
  end

  class << self

    def text_search text
      cond = []
      [:permalink, :title, :alternative_title, :old_title, :old_alternative_title].each do |field|
        cond << ["places.#{field} ILIKE ?", "%#{text}%"]
      end

      result = [cond.map { |q, p| q }.join(' OR ')]
      cond.map { |q, p| result << p }
      scoped :conditions => result.flatten
    end

    def search_order num
      ORDER_CONVERSION[num.to_i]
    end

    def recommended(city_id = 1)
      Place.not_demo.city(city_id).visible.all(:limit => 3)
    end

    def popular
      RedisLogger.get_param("popular_places").blank? ? [] : RedisLogger.get_param("popular_places")
    end

    def production
      not_demo.visible.financial_checked
    end

    def records
      where("places.id > 0")
    end

    def referable_collection
      not_demo.sorted.includes(:city).map{ |pl| [ "#{pl.title} - #{pl.id} - #{pl.city.permalink}", pl.id ] }.sort_by{|arr| arr.first} unless Rails.env.test?
    end

    def es_observer(opts)
      data = es_autocomplete(opts)
      # enrich_stats(opts, data)

      data
    end

    def enrich_stats(opts, data)
      sr = StatEnricher.new(opts)
      sr.enrich_missing_search_stats if data.blank?
      sr.enrich_search_stats
    end
  end

private

  def set_defaults
    self.permalink = rand(100000000000).to_s unless permalink
  end

  def reset_contract_id
    self.contract_id = nil unless agent.contracts.map(&:id).include?(contract_id)
  end

  def prevent_scaffold_bugs
    self.banquet_from = nil if banquet_from.to_i == 0
    self.banquet_percent = 0.1 if banquet_percent.blank?
  end

  def create_financial_months
    epoch = Date.new(2012,12,1)
    month_count = (Date.today.year * 12 + Date.today.month) - (epoch.year * 12 + epoch.month) - 1
    (0..month_count).each do |m|
      FinancialMonth.create do |fm|
        fm.place = self
        fm.month_start = epoch + m.month
      end
    end
  end

  def send_break_notify
    Notifier.delay({:run_at => break_notify_at}).place_break(self)
  end

  def set_mobile_map_url
    unless Rails.env.test?
      update_attribute(:mobile_map_url, Googl.shorten("http://m.gettable.ru/places/#{id}/map", '95.213.135.109', 'AIzaSyChUlPXw65bUXP1iBcu9bokT1-larcxy1U').short_url)
    end
  end

  def renew_landing_updated_at
    self.landing_updated_at = Time.zone.now
  end

  def renew_seo_updated_at
    self.seo_updated_at = Time.zone.now
  end

  def renew_banquet_updated_at
    self.banquet_updated_at = Time.zone.now
  end

  def renew_launch_fields
    new_state = visible && financial_checked
    prev_state = visible_was && financial_checked_was
    unless new_state == prev_state
      if new_state
        self.launched_at = Time.zone.now
      else
        self.stopped_at = Time.zone.now
      end

      history_obj = { :time => Time.zone.now, :state => new_state }

      unless active?
        history_obj.merge!({ :kind => break_kind, :description => break_description, :responsible_id => break_responsible_id })
      end

      if launch_history.present?
        self.launch_history = (JSON.parse(launch_history) << history_obj).to_json
      else
        self.launch_history = [history_obj].to_json
        self.launch_from = Date.today unless launch_from
      end
    end
  end

end
