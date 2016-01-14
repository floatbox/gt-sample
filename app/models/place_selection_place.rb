class PlaceSelectionPlace < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper

  belongs_to :place
  belongs_to :place_selection

  validates_presence_of :place, :place_selection
  validates_uniqueness_of :place_id, :scope => :place_selection_id

  delegate :address, :main_banquet_image, :specialization, :title, :likes, :to => :place

  def order_rooms
    @order_rooms ||= OrderRoom.all(:conditions => ['id IN (?)', order_room_ids.split(',')])
  end

  def room_prices
    @room_prices ||= order_rooms.map{ |room| room.calculate_price(place_selection.persons) }
  end

  def room_prices_explained
    if room_prices.min == room_prices.max
      "#{number_to_currency(room_prices.max, :precision => 0)}"
    else
      "от #{number_to_currency(room_prices.min, :precision => 0)} до #{number_to_currency(room_prices.max, :precision => 0)}"
    end
  end

end
