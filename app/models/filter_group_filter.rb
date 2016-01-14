class FilterGroupFilter < ActiveRecord::Base

  belongs_to :filter_group
  belongs_to :search_filter

  acts_as_list :scope => :filter_group, :top_of_list => 0

  validates_presence_of :filter_group, :search_filter
  validates_uniqueness_of :search_filter_id, :scope => :filter_group_id

end
