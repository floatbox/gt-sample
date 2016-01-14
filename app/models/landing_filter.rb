class LandingFilter < ActiveRecord::Base
  
  belongs_to :landing
  belongs_to :search_filter

  validates_presence_of :landing, :search_filter
  validates_uniqueness_of :search_filter_id, :scope => :landing_id

end