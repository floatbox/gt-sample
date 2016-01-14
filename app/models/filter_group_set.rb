class FilterGroupSet < ActiveRecord::Base

  has_many :cities, foreign_key: :iphone_filter_group_set_id
  has_many :filter_group_filter_group_sets, dependent: :destroy
  has_many :filter_groups, through: :filter_group_filter_group_sets
  has_many :landings

  belongs_to :city

  scope :mobile, -> { where(kind: 'mobile') }

  def self.mobile_set
    mobile.take
  end

  def to_label
    "#{id} - #{internal_name}"
  end
end
