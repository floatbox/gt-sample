object current_place

attributes :id, :title, :zones, :address_without_city, :min_persons,
  :max_persons, :specialization, :specialization_icon, :avg_price_category, :preferred_category

node(:soon_place) { current_place.present? && current_place.soon? }
node(:not_found) { current_place.blank? }
node(:last_booking) { @last_booking }
