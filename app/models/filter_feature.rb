class FilterFeature < ActiveRecord::Base
  belongs_to :feature
  belongs_to :search_filter
  
  validates_presence_of :search_filter, :feature
  validates_uniqueness_of :feature_id, :scope => :search_filter_id  
end