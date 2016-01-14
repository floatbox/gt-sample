object @place

attributes :id, :title, :longitude, :latitude, :review_count, :our_review,
           :landing_link, :address, :metro_station_name, :description, :likes,
           :search_map_image, :link, :show_pdf_menu

node(:created_at)           { |p| p.created_at.to_i * 1000 }

node(:properties) do |p|
  { id: p.id, hintContent: p.title }
end

node(:geometry) do |p|
  { type: 'Point', coordinates: [p.longitude, p.latitude] }
end

node(:birthday_discount, :if => lambda{ |p| @birthday_discount }){ |p| p.birthday_discount }
node(:birthday_offer, :if => lambda{ |p| @birthday_discount }){ |p| p.birthday_offer }
node(:special_alert, :if => lambda{ |p|  @until_late }){ |p| p.today_until_working_time }

child(root_object.menu_categories.with_active_menu_items => :menu_categories) do
  extends "site/menu_categories/show"
end

child(root_object.menu_items.production.promo => :favorite_menu_category) do
  extends "site/menu_items/show"
end

child(root_object.place_photos.main_landing => :place_photos) do
  extends "site/place_photos/show"
end

child(root_object.reviews.includes(:booking).moderated.visited.with_description.bub_sorted(@sort_review_id).limit(2) => :reviews) do
  extends "site/reviews/show"
end

child(root_object.pdf_menus.visible => :pdf_menus) do
  extends "site/pdf_menus/show"
end
