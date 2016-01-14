class City < ActiveRecord::Base

  ALL    = ['msk', 'spb', 'ekb', 'kazan', 'kiev', 'nn']
  ACTIVE = ['msk', 'spb', 'ekb', 'kazan']

  acts_as_list

  geocoded_by :name do |obj, results|
    if geo = results.first
      obj.latitude    = geo.latitude
      obj.longitude   = geo.longitude
      obj.state       = State.where(:name => geo.state).first_or_create
    end
  end

  belongs_to :country
  belongs_to :state
  belongs_to :iphone_filter_group_set, :class_name => 'FilterGroupSet'

  has_many :city_place_groups, :dependent => :destroy
  has_many :contracts
  has_many :iphone_landings
  has_many :mobile_landings
  has_many :site_landings
  has_many :metro_stations
  has_many :places
  has_many :place_groups, :through => :city_place_groups
  has_many :users
  has_many :topics
  has_many :filter_group_set
  has_many :gifts

  validates_presence_of :country, :general_phone, :iphone_filter_group_set
  validates_presence_of :name, :permalink, :name_r, :name_p

  named_scope :launched, :conditions => { :active => true }
  named_scope :soon, :conditions => { :active => false }
  named_scope :limited, lambda {|number| { :limit => number }}
  named_scope :without_other_city, :conditions => ['permalink != ?', 'drugoi']
  named_scope :sorted, :order => 'position asc'


  after_validation :geocode, :if => lambda { name.present? && name_changed? }

  def russian?
    country.russian?
  end

  def msk?
    permalink == 'msk'
  end

  def spb?
    permalink == 'spb'
  end

  def ekb?
    permalink == 'ekb'
  end

  def kazan?
    permalink == 'kazan'
  end

  def short
    short_name || name
  end

  def msk_timezone_offset
    time1 = Time.zone.now.in_time_zone("Europe/Moscow")
    time2 = Time.zone.now.in_time_zone(time_zone)
    (time2.utc_offset - time1.utc_offset)/3600
  end

  def msk_timezone_offset_str
    if msk_timezone_offset != 0
      "#{'+' if msk_timezone_offset > 0}#{msk_timezone_offset} #{Russian::p(msk_timezone_offset.abs, 'час', 'часа', 'часов')}"
    end
  end

  def self.by_id_or_permalink(value)
    if value =~ /\d/
      self.find_by_id(value.to_i)
    else
      self.find_by_permalink(value)
    end
  end

  def self.launched_in_state(state)
    self.launched.pluck(:region).include? state
  end

  def self.geolocate(location)
    return fallback unless location.present?

    lat = location.data['lat'].to_f
    lng = location.data['lng'].to_f

    near([lat, lng], 50).try(:first) || fallback
  end

  def self.fallback
    find(1)
  end

  def coordinates
    [ latitude, longitude ]
  end

  def location
    [ longitude, latitude ]
  end

  def resto_count
    @resto_count ||= Rails.cache.fetch("city_#{id}_resto_count", expires_in: 6.hours) do
      places.production.count
    end
  end

  def approximate_resto_count
    @approximate_resto_count ||= Rails.cache.fetch("city_#{id}_approx_resto_count", expires_in: 6.hours) do
      if (count = places.production.count) > 50
        ((count - 1) / 50) * 50
      else
        ((count - 1) / 5) * 5
      end
    end
  end

  def serialize
    { location: location, name_r: name_r }.to_json
  end

  def host
    msk? ? 'https://gettable.ru' : "https://#{permalink}.gettable.ru"
  end

end
