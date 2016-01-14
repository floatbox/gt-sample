class PlacePhoto < ActiveRecord::Base

  belongs_to :place
  belongs_to :gallery, counter_cache: true

  has_many :tagged_items, :as => :item, :dependent => :destroy
  has_many :tags, :through => :tagged_items

  acts_as_list :scope => :gallery, :top_of_list => 0
  has_attached_file :photo, { styles: { small: ['64x64#', 'jpg'],
                                        landing: ['600x400#', 'jpg'],
                                        gallery: ['174x', 'jpg'],
                                        iphone: ['320x260#', 'jpg'],
                                        iphone_2x: ['640x520#', 'jpg'],
                                        iphone_3x: ['960x780#', 'jpg'],
                                        iphone_preview: ['32x26#', 'jpg'],
                                        iphone_preview_2x: ['64x52#', 'jpg'],
                                        iphone_preview_3x: ['96x78#', 'jpg'],
                                        iphone_booking: ['60x', 'jpg'],
                                        iphone_booking_2x: ['120x', 'jpg'],
                                        iphone_booking_3x: ['180x', 'jpg'],
                                        search_results: ['305x170#', 'jpg'],
                                        search_map: ['114x114#', 'jpg'],
                                        search: ['313x203#', 'jpg'],
                                        similar: ['270x203#', 'jpg'],
                                        main_search: ['600x350#', 'jpg'],
                                        widget_similar: ['119x79#', 'jpg'],
                                        mobile_list_2x: ['734x160#', 'jpg'],
                                        mobile_list_3x: ['1194x240#', 'jpg'],
                                        mobile_card_2x: ['750x465#', 'jpg'],
                                        mobile_card_3x: ['1242x698#', 'jpg'],
                                        mobile_gallery_2x: ['750x', 'jpg'],
                                        mobile_gallery_3x: ['1242х', 'jpg'],
                                        mobile_gallery_preview_2x: ['208x208#', 'jpg'],
                                        mobile_gallery_preview_3x: ['312x312#', 'jpg'] },
                              convert_options: { iphone: "-quality 75",
                                                 iphone_2x: "-quality 75",
                                                 iphone_3x: "-quality 75",
                                                 landing: "-quality 80",
                                                 mobile_list_2x: "-quality 60",
                                                 mobile_list_3x: "-quality 60",
                                                 mobile_card_2x: "-quality 60",
                                                 mobile_card_3x: "-quality 60",
                                                 mobile_gallery_2x: "-quality 60",
                                                 mobile_gallery_3x: "-quality 60",
                                                 mobile_gallery_preview_2x: "-quality 60",
                                                 mobile_gallery_preview_3x: "-quality 60" },
                              path: "bars/:place_id/photos/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_presence_of :place
  validates_attachment_presence :photo
  validates_attachment_content_type :photo, content_type: /\Aimage\/.*\Z/

  named_scope :main_landing, :conditions => 'main_landing = true'
  named_scope :gallery, :conditions => ['gallery is not null']
  named_scope :for_place, lambda {|place_id| { :conditions => {:place_id => place_id} }}
  named_scope :sorted, :order => 'position asc'

  default_scope { sorted }

  def small
    photo.url(:small)
  end

  def landing
    photo.url(:landing)
  end


  def iphone
    photo.url(:iphone) if photo_file_name
  end

  def iphone_2x
    photo.url(:iphone_2x) if photo_file_name
  end

  def iphone_3x
    photo.url(:iphone_3x) if photo_file_name
  end

  def iphone_preview
    photo.url(:iphone_preview) if photo_file_name
  end

  def iphone_preview_2x
    photo.url(:iphone_preview_2x) if photo_file_name
  end

  def iphone_preview_3x
    photo.url(:iphone_preview_3x) if photo_file_name
  end

  def iphone_booking
    photo.url(:iphone_booking) if photo_file_name
  end

  def iphone_booking_2x
    photo.url(:iphone_booking_2x) if photo_file_name
  end

  def iphone_booking_3x
    photo.url(:iphone_booking_3x) if photo_file_name
  end

  def similar
    photo.url(:similar) if photo_file_name
  end

  def mobile_list_2x
    photo.url(:mobile_list_2x) if photo_file_name
  end

  def mobile_list_3x
    photo.url(:mobile_list_3x) if photo_file_name
  end

  def mobile_card_2x
    photo.url(:mobile_card_2x) if photo_file_name
  end

  def mobile_card_3x
    photo.url(:mobile_card_3x) if photo_file_name
  end

  def mobile_gallery_2x
    photo.url(:mobile_gallery_2x) if photo_file_name
  end

  def mobile_gallery_3x
    photo.url(:mobile_gallery_3x) if photo_file_name
  end

  def mobile_gallery_preview_2x
    photo.url(:mobile_gallery_preview_2x) if photo_file_name
  end

  def mobile_gallery_preview_3x
    photo.url(:mobile_gallery_preview_3x) if photo_file_name
  end

  def search
    photo.url(:search_results)
  end

  def new_search
    photo.url(:search)
  end

  def search_map
    photo.url(:search_map)
  end

  def main_search
    photo.url(:main_search)
  end

end
