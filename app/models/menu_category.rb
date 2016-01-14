class MenuCategory < ActiveRecord::Base
  extend Enumerize

  belongs_to :place
  belongs_to :menu_global_category

  has_many :menu_sub_categories
  has_many :menu_items
  has_many :direct_menu_items, -> { where(menu_sub_category_id: nil) },
           class_name: 'MenuItem'

  validates :place, :name, presence: true
  validates :name, uniqueness: { scope: :place_id }

  default_scope { order(position: :asc) }

  scope :sorted,      -> { order(position: :asc) }
  scope :with_global, -> { where.not(menu_global_category_id: nil) }
  scope :checked,     -> { where.not(checked_at: nil) }

  def checked?
    checked_at?
  end

  def self.with_active_menu_items
    ids = joins(:menu_items)
          .select('menu_categories.id')
          .group('menu_categories.id')
          .having('count(menu_items.id) > 2')
          .where.not(menu_items: { checked_at: nil, deleted: true })
          .references(:menu_items)

    where(id: ids.to_a)
  end
end
