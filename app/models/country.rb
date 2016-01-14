class Country < ActiveRecord::Base
  has_many :cities
  
  def russian?
    permalink == 'russia'
  end
  
end