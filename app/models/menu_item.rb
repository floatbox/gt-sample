class MenuItem < ActiveRecord::Base
  include ActsAsBooleanTime

  acts_as_boolean_time :checked_at

  belongs_to :place
  belongs_to :menu_category
  belongs_to :menu_sub_category

  validates_presence_of :place, :menu_category, :name
  validates_uniqueness_of :name, :scope => [:menu_category_id, :menu_sub_category]
  validates_numericality_of :price, :greater_than => 0, :allow_blank => true
  validates_uniqueness_of :json_raw, :scope => [:menu_category_id, :menu_sub_category]

  scope :sorted, -> { order(position: :asc) }
  scope :by_price, -> { order(price: :asc) }
  scope :checked, -> { where.not(checked_at: nil) }
  scope :unchecked, -> { where(checked_at: nil) }
  scope :promo, -> { where(promo: true) }
  scope :with_price, -> { where.not(price: nil) }
  scope :active, -> { where.not(checked_at: nil, deleted: true) }
  scope :production, -> { active.sorted }

  # Predicates

  def checked?
    checked_at.present?
  end

end
