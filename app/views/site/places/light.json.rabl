object @place

attributes :id, :title, :today_working_time, :likes, :address,
           :longitude, :latitude, :search_map_image, :link,
           :search_image, :main_search_image, :interesting_detail, :specialization,
           :description, :avg_price


node(:avg_price_str){ |p| p.stringify_avg_price }
node(:birthday_discount, :if => lambda{ |p| params[:search] && params[:search].include?('birthday_discount') }){ |p| p.birthday_discount }
node(:birthday_offer, :if => lambda{ |p| params[:search] && params[:search].include?('birthday_discount') }){ |p| p.birthday_offer }
node(:special_alert, :if => lambda{ |p|  params[:search] && params[:search].include?('until_late') }){ |p| p.today_until_working_time }
node(:promo) { |p| p.general_promo_action(params) }

child(:metro_station){ extends "site/metro_stations/show" }
