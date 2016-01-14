class IphoneLanding < Landing

  acts_as_list

  has_attached_file :photo, { :styles => { main:       ['320x140#', 'png'],
                                           main_2x:    ['640x280#', 'png'],
                                           main_3x:    ['960x420#', 'png'],
                                           preview:    ['32x14#', 'png'],
                                           preview_2x: ['64x28#', 'png'],
                                           preview_3x: ['96x42#', 'png'],
                                           feed_2x:    ['718x320', 'jpg'],
                                           feed_3x:    ['1194x480', 'jpg'],
                                           topic_2x:   ['750x464#', 'jpg'],
                                           topic_3x:   ['1242x696#', 'jpg'] },
                              convert_options: { feed_2x: "-quality 70",
                                                 feed_3x: "-quality 70",
                                                 topic_2x: "-quality 70",
                                                 topic_3x: "-quality 70" },
                              :path => "trends/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_attachment_content_type :photo, :content_type => /image/

  scope :sorted,    -> { order(position: :asc) }
  scope :for_today, -> { where('date_from <= ? AND date_to >= ?', Date.today, Date.today) }

  def photo_main
    photo.url(:main) if photo_file_name
  end

  def photo_main_2x
    photo.url(:main_2x) if photo_file_name
  end

  def photo_main_3x
    photo.url(:main_3x) if photo_file_name
  end

  def photo_preview
    photo.url(:preview) if photo_file_name
  end

  def photo_preview_2x
    photo.url(:preview_2x) if photo_file_name
  end

  def photo_preview_3x
    photo.url(:preview_3x) if photo_file_name
  end

  def photo_feed_2x
    photo.url(:feed_2x) if photo_file_name
  end

  def photo_feed_3x
    photo.url(:feed_3x) if photo_file_name
  end

  def photo_topic_2x
    photo.url(:topic_2x) if photo_file_name
  end

  def photo_topic_3x
    photo.url(:topic_3x) if photo_file_name
  end

end
