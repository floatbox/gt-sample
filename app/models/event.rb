class Event < ActiveRecord::Base

  KINDS = { 'music' => { 'live_music' => 'Живая музыка',
                        'rock_concert' => 'Рок-концерт' },
            'party' => { 'cowboy_party' => 'Ковбойская вечеринка' },
            'masterclass' => { 'cooking_sushi' => 'Мастер-класс по приготовлению суши' },
            'another' => {} }

  belongs_to :place

  has_attached_file :photo, { styles: { small: ['64x64#', 'jpg'],
                                        landing: ['600x400#', 'jpg'],
                                        gallery: ['174x', 'jpg'],
                                        mobile_list_2x: ['734x160#', 'jpg'],
                                        mobile_list_3x: ['1194x240#', 'jpg'],
                                        mobile_card_2x: ['750x465#', 'jpg'],
                                        mobile_card_3x: ['1242x698#', 'jpg'],
                                        mobile_gallery_2x: ['750x', 'jpg'],
                                        mobile_gallery_3x: ['1242x', 'jpg'],
                                        mobile_gallery_preview_2x: ['208x208#', 'jpg'],
                                        mobile_gallery_preview_3x: ['312x312#', 'jpg'] },
                              convert_options: { landing: "-quality 80",
                                                 mobile_list_2x: "-quality 60",
                                                 mobile_list_3x: "-quality 60",
                                                 mobile_card_2x: "-quality 60",
                                                 mobile_card_3x: "-quality 60",
                                                 mobile_gallery_2x: "-quality 60",
                                                 mobile_gallery_3x: "-quality 60",
                                                 mobile_gallery_preview_2x: "-quality 60",
                                                 mobile_gallery_preview_3x: "-quality 60" },
                              path: "events/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  just_define_datetime_picker :start_at
  just_define_datetime_picker :end_at

  validates_presence_of :place
  validates_presence_of :title, :description, :start_at

  validates_inclusion_of :kind, in: KINDS.keys
  validates_inclusion_of :subkind, in: KINDS.values.map(&:keys).flatten
  validates_attachment_content_type :photo, content_type: ['image/jpeg', 'image/pjpeg', 'image/jpg']

  delegate :landing_link, :mobile_sharing_link, to: :place, prefix: true

  scope :for_today, -> { where('start_at > ? and start_at <= ?', 1.hour.ago.utc, Date.tomorrow.to_time.utc) }
  scope :future,    -> { where('start_at > ?', 1.hour.ago.utc) }
  scope :sorted,    -> { order(start_at: :asc) }
  scope :limited,   -> { limit(7) }
  scope :place_limited,   -> { limit(3) }

  def subkind_stringify
    KINDS[kind][subkind]
  end

  def time_period(for_today = false)
    prefix = for_today ? "" : "#{Russian::strftime(start_at, '%e %B, ')}"
    if end_at
      "#{prefix}c #{start_at.strftime('%k:%M')} до #{end_at.strftime('%k:%M')}".strip
    else
      "#{prefix}начало в #{start_at.strftime('%k:%M')}".strip
    end
  end

  def time
    start_at.strftime('%H:%M')
  end

  def date
    start_at.strftime('%Y-%m-%d')
  end

  def mobile_sharing_text
    "#{title} #{time_period}"
  end

  def iphone_photo
    place.iphone_booking_image
  end

  def iphone_photo_2x
    place.iphone_booking_image_2x
  end

  def iphone_photo_3x
    place.iphone_booking_image_3x
  end

  def small
    photo.url(:small)
  end

  def landing
    photo.url(:landing)
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

end
