class FavouritePlace < ActiveRecord::Base

  belongs_to :user
  belongs_to :place

  validates_presence_of   :place, :user
  validates_uniqueness_of :user_id, scope: :place_id

  scope :sorted, -> { order(created_at: :desc) }

end
