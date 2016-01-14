class State < ActiveRecord::Base
  belongs_to :country
  has_many   :cities

  validates_presence_of :name, :country

  before_validation :set_country, :if => lambda { country.nil? }

  named_scope :launched, :conditions => { :active => true }

  private

  def set_country
    geo = Geocoder.search(name).first
    self.country = Country.where(:name => geo.country, :permalink => geo.country_code).first_or_create if geo.present?
  end

end
