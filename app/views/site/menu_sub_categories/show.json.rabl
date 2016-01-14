object @menu_sub_category

attributes :name

child(root_object.menu_items.active.sorted => :menu_items ){ extends "site/menu_items/show" }
