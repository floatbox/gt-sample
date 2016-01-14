 class Feature < ActiveRecord::Base
  KINDS = { 'feature'    => 'особенность',
            'trend'      => 'тренд',
            'atmosphere' => 'атмосфера',
            'subtype'    => 'подтип',
            'cuisine'    => 'кухня',
            'terrace'    => 'веранда',
            'mobile'     => 'мобильный',
            'badge'      => 'бейдж' }

  SPECIALIZATIONS = %w( cuisine subtype feature )

  has_attached_file :menu_photo, { styles: { iphone: ['320x96#', 'png'],
                                             iphone_2x: ['640x192#', 'png'],
                                             iphone_3x: ['960x288#', 'png'] },
                                   path: "features/:id/:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :icon_gray, { styles: { iphone: ['62x62#', 'png'],
                                            iphone_2x: ['124x124#', 'png'],
                                            iphone_3x: ['186x186#', 'png'],
                                            site: ['62x62#', 'png'],
                                            site_2x: ['124x124#', 'png'],
                                            site_3x: ['186x186#', 'png'] },
                                  path: "features/:id/icon_gray_:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :icon_coloured, { styles: { iphone: ['62x62#', 'png'],
                                                iphone_2x: ['124x124#', 'png'],
                                                iphone_3x: ['186x186#', 'png'],
                                                site: ['62x62#', 'png'],
                                                site_2x: ['124x124#', 'png'],
                                                site_3x: ['186x186#', 'png'] },
                                      path: "features/:id/icon_coloured_:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :mobile_icon, { styles: { mobile_2x: ['160x160#', 'png'],
                                              mobile_3x: ['240x240#', 'png'] },
                                    path: "features/:id/mobile_icon_:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_many :children, class_name: 'Feature', foreign_key: :parent_id, inverse_of: :children
  has_many :place_features, inverse_of: :feature
  has_many :places, through: :place_features
  has_many :filter_features
  has_many :search_filters, through: :filter_features
  has_many :landings, through: :search_filters
  has_many :site_landings,
           -> { where(landings: { type: 'SiteLanding' }) },
           through: :search_filters, source: :landings

  belongs_to :referable, polymorphic: true
  belongs_to :parent, class_name: 'Feature', foreign_key: :parent_id, inverse_of: :parent

  validates_inclusion_of :kind,  in: KINDS.keys
  validates_presence_of :kind, :title
  validates_attachment_content_type :menu_photo, :content_type => /image/, :allow_blank => true

  scope :sorted,           -> { order(id: :asc) }
  scope :without_children, -> { where(parent_id: nil) }
  scope :with_menu_photo,  -> { where.not(menu_photo_file_name: nil) }
  scope :with_mobile_icon, -> { where.not(mobile_icon_file_name: nil) }
  scope :show_in_tags,     -> { without_children.where.not(kind: %w(trend atmosphere mobile)) }
  scope :kinds,   ->(*kinds)  { where(kind: kinds) }

  def city_landings(city_id)
    landings.where(city_id: city_id)
  end

  def icon_gray_2x
    icon_gray.url(:site_2x) if icon_gray_file_name
  end

  def mobile_icon_2x
    mobile_icon.url(:mobile_2x) if mobile_icon_file_name
  end

  def mobile_icon_3x
    mobile_icon.url(:mobile_3x) if mobile_icon_file_name
  end

  def first_site_landing
    site_landings.first
  end

  def kind_str
    KINDS[kind]
  end

  def basic_serialization
    attributes.slice( *%w(id title specialization kind emoji mobile_icon_2x mobile_icon_3x text) )
  end

end
