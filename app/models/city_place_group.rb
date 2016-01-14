class CityPlaceGroup < ActiveRecord::Base
  belongs_to :city
  belongs_to :place_group
end
