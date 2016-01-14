class Post < ActiveRecord::Base

  has_many :post_parts, :order => 'position ASC'
  has_many :tagged_items, :as => :item, :dependent => :destroy
  has_many :tags, :through => :tagged_items

  has_attached_file :photo, {
    :styles => {
      :small => ['250x200#', 'jpg']
    },
    :path => "blog/photos/:id/:style.jpg"
  }.merge(PAPERCLIP_STORAGE_OPTIONS)

  accepts_nested_attributes_for :post_parts


  before_validation :set_permalink, :unless => :permalink?

  named_scope :published, lambda { { :conditions => ['published_at < ?', Time.zone.now] } }
  named_scope :by_views, :order => "views DESC"

  validates_presence_of :title, :permalink, :description
  validates_uniqueness_of :permalink
  validates_attachment_content_type :photo, :content_type => /image/, :allow_blank => true


  def self.popular(limit = 3)
    Post.published.by_views.limit(limit)
  end

  def self.popular_tags(limit = 5)
    Tag.top('Post', limit)
  end

  # Attributes like

  def popular(limit = 3)
    Post.published.by_views.where.not(:id => id).limit(limit)
  end

  def views_floor
    57 + id % 57
  end

  def total_views
    views_floor + views
  end

  # Predicates

  def published?
    published_at < Time.zone.now if published_at?
  end

  # Methods

  def increment_views
    increment!(:views)
  end

  def to_param
    permalink
  end

  private

  def set_permalink
    self.permalink = title.parameterize
  end

end
