class MenuGlobalCategory < ActiveRecord::Base
  acts_as_list

  has_many :menu_categories

  has_attached_file :iphone_icon,
                    { styles: { show:    ['18x27#', 'jpg'],
                                show_2x: ['36x54#', 'jpg'],
                                show_3x: ['54x81#', 'jpg'] },
                      path: 'menu_global_categories/:id/iphone_icon/:style.jpg'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :site_icon,
                    { styles: { show:    ['64x64#',   'png'],
                                show_2x: ['600x400#', 'jpg'],
                                show_3x: ['192x192#', 'jpg'] },
                      path: 'menu_global_categories/:id/site_icon/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :site_icon_active,
                    { styles: { show:    ['64x64#',   'png'],
                                show_2x: ['600x400#', 'jpg'] },
                      path: 'menu_global_categories/:id/site_icon/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :mobile_icon,
                    { styles: { show:    ['48x48#',   'png'],
                                show_2x: ['72x72#', 'png'],
                                show_3x: ['144x144#', 'png'] },
                      path: 'menu_global_categories/:id/mobile_icon/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  scope :sorted, -> { order(:position) }

  validates :title, presence: true

  validates_attachment_content_type :iphone_icon, :site_icon,
                                    content_type: /image/, allow_blank: true

  validates_attachment_content_type :mobile_icon, content_type: ["image/png"], allow_blank: true

  def menu_categories_for(place)
    menu_categories.where(place: place)
  end

  def iphone_icon_show
    iphone_icon.url(:show) if iphone_icon_file_name
  end

  def iphone_icon_show_2x
    iphone_icon.url(:show_2x) if iphone_icon_file_name
  end

  def iphone_icon_show_3x
    iphone_icon.url(:show_3x) if iphone_icon_file_name
  end

  def mobile_icon_show
    mobile_icon.url(:show) if mobile_icon_file_name
  end

  def mobile_icon_show_2x
    mobile_icon.url(:show_2x) if mobile_icon_file_name
  end

  def mobile_icon_show_3x
    mobile_icon.url(:show_3x) if mobile_icon_file_name
  end

end
