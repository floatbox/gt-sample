object @menu_category

attributes :name

child(root_object.menu_sub_categories.with_active_menu_items => :menu_sub_categories) { extends "site/menu_sub_categories/show" }

if root_object.direct_menu_items.active.any?
  child(root_object.direct_menu_items.active.sorted => :menu_items){ extends "site/menu_items/show" }
end
