class Promo < ActiveRecord::Base

  has_attached_file :image, { :styles => { :site => ['280x90#', 'png'] },
                              :path => "promos/:id/:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)
  has_attached_file :terms, { :path => "promos/:id/terms.pdf" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_attachment_content_type :image, :content_type => ["image/jpg", "image/jpeg", "image/png"], :allow_blank => true
  validates_attachment_content_type :terms, :content_type => ['application/pdf'], :allow_blank => true

  has_and_belongs_to_many :places

  validates :title, :kind, :date_from, :date_to, presence: true
  validates :kind, uniqueness: true

  scope :active, -> { where('enabled = true AND date_from <= :date AND date_to >= :date', date: Date.today) }

  def site_image
    image.url(:site)
  end

end
