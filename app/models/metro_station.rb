class MetroStation < ActiveRecord::Base
  include AssociationsPlaceReindex

  METRO_COLORS = {
    '#ef3f54' => 'красная', '#44b85c' => 'зелёная', '#0078bf' => 'синяя',  '#19c1f3' => 'голубая',
    '#894e35' => 'кольцевая', '#f58631' => 'оранжевая', '#8e479c' => 'фиолетовая', '#ffcb31' => 'жёлтая',
    '#b1b1b2' => 'серая', '#b3d445' => 'салатовая', '#79cdcd' => 'бирюзовая', '#acbfe1' => 'серо-голубая'
  }

  REMOTENESS_STR = { 1 => 'садовое', 2 => 'трешка', 3 => 'мкад' }

  SEARCH_RADIUS_CONFIG = { 1 => { :max_radius => 1,
                                  :min_places => 40,
                                  :step => 0.2 },
                           2 => { :max_radius => 1.8,
                                  :min_places => 30,
                                  :step => 0.2 },
                           3 => { :max_radius => 2.6,
                                  :min_places => 20,
                                  :step => 0.5 } }

  belongs_to :city
  has_many :places

  validates_presence_of  :city
  validates_presence_of  :name
  validates_inclusion_of :branch_color, :in => METRO_COLORS.keys, :allow_blank => true
  validates_uniqueness_of :permalink, :scope => :city_id

  named_scope :city, lambda {|city| { :conditions => ['city_id = ?', city.to_i] }}
  named_scope :sorted, :order => 'name asc'

  after_create  :add_search_filter
  after_destroy :remove_search_filter

  def coordinates?
    longitude && latitude
  end

  def coordinates
    if coordinates?
      [latitude, longitude]
    else
      delay.fetch_coordinates
      nil
    end
  end

  def location
    coordinates.reverse
  end

  def fetch_coordinates
    unless coordinates?
      result = Geocoder.coordinates full_address
      if result.present?
        update_attributes! :longitude => result[1], :latitude => result[0]
      end
    end
  end

  def full_address
    "#{city.name}, метро #{name}"
  end

  def add_search_filter
    SearchFilter.create(:kind => "metro", :value => "metro_#{id}", :title => name, :short_title => name)
  end

  def remove_search_filter
    SearchFilter.first(:conditions => {:kind => "metro", :value => "metro_#{id}"}).delete
  end

  def landing_link
    "#{'/msk' if city_id == 1}/metro/#{permalink}"
  end

  def landing_link_with_host
    "https://#{city.permalink + '.' unless city_id == 1 }gettable.ru#{landing_link}"
  end

  def to_label
    "#{name} (#{city.name})"
  end

end
