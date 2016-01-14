class Tag < ActiveRecord::Base
  has_many :tagged_items, :dependent => :destroy
  has_many :place_photos, :through => :tagged_items, :source => :item, :source_type => "PlacePhoto"
  has_many :places, :through => :tagged_items, :source => :item, :source_type => "Place"
  has_many :search_filters, :through => :tagged_items, :source => :item, :source_type => "SearchFilter"
  has_many :posts, :through => :tagged_items, :source => :item, :source_type => "Post"

  validates_presence_of :title
  validates_uniqueness_of :title

  named_scope :for_photo, :conditions => 'for_photo = true'
  named_scope :for_booking_features, :conditions => 'for_booking_features = true'
  named_scope :for_post, :conditions => 'for_post = true'

  def self.top(type, limit)
    self.select("tags.*, count(tagged_items.id) AS tags_count") \
      .joins(:tagged_items) \
      .group("tags.id") \
      .where("tagged_items.item_type = ?", type) \
      .order("tags_count DESC") \
      .limit(limit)
  end

end
