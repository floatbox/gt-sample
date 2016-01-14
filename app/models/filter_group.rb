class FilterGroup < ActiveRecord::Base
  KINDS = %w( site_landing site_search site_index site_resto_landing site_bars_landing site_metro_landing mobile )

  has_many :filter_group_filters, :dependent => :destroy
  has_many :search_filters, :through => :filter_group_filters, :order => 'filter_group_filters.position'
  has_many :filter_group_filter_group_sets, :dependent => :destroy
  has_many :filter_group_sets, :through => :filter_group_filter_group_sets

  validates_presence_of :value

  def iphone_bottom?
    kind == 'bottom'
  end

  def to_label
    internal_name? ? internal_name : title
  end
end
