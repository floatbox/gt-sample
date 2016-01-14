class MenuSubCategory < ActiveRecord::Base
  belongs_to :place
  belongs_to :menu_category

  has_many :menu_items

  validates_presence_of :place, :menu_category, :name
  validates_uniqueness_of :name, :scope => :menu_category_id

  default_scope -> { order(position: :asc) }

  scope :sorted, -> { order(position: :asc) }
  scope :checked, -> { where.not(checked_at: nil) }
  scope :with_active_menu_items, -> { includes(:menu_items).merge(MenuItem.active) }

  def checked?
    checked_at.present?
  end

end
