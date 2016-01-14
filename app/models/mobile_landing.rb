class MobileLanding < Landing

  acts_as_list

  has_attached_file :icon_gray, { :styles => { :main => ['48x48#', 'png'],
                                               :main_2x => ['96x96#', 'png'],
                                               :main_3x => ['144x144#', 'png'] },
                              :path => "mobile_landings/:id/icon_gray_:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :icon_coloured, { :styles => { :main => ['48x48#', 'png'],
                                                   :main_2x => ['96x96#', 'png'],
                                                   :main_3x => ['144x144#', 'png'] },
                              :path => "mobile_landings/:id/icon_coloured_:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_attachment_content_type :icon_gray, :content_type => /image/, :allow_blank => true
  validates_attachment_content_type :icon_coloured, :content_type => /image/, :allow_blank => true

  has_attached_file :photo, { :styles => { main:       ['320x140#', 'jpg'],
                                           feed_2x:    ['718x320', 'jpg'],
                                           feed_3x:    ['1194x480', 'jpg'],
                                           topic_2x:   ['750x464#', 'jpg'],
                                           topic_3x:   ['1242x696#', 'jpg'] },
                              convert_options: { feed_2x: "-quality 70",
                                                 feed_3x: "-quality 70",
                                                 topic_2x: "-quality 70",
                                                 topic_3x: "-quality 70" },
                              :path => "mobile_landings/:id/photo_:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_attachment_content_type :photo, :content_type => /image/

  scope :sorted,    -> { order(position: :asc) }
  scope :for_today, -> { where('(date_from IS NULL OR date_from <= ?) AND (date_to IS NULL OR date_to >= ?)', Date.today, Date.today) }

  def icon_gray_main
    icon_gray.url(:main) if icon_gray_file_name
  end

  def icon_gray_main_2x
    icon_gray.url(:main_2x) if icon_gray_file_name
  end

  def icon_gray_main_3x
    icon_gray.url(:main_3x) if icon_gray_file_name
  end

  def icon_coloured_main
    icon_coloured.url(:main) if icon_coloured_file_name
  end

  def icon_coloured_main_2x
    icon_coloured.url(:main_2x) if icon_coloured_file_name
  end

  def icon_coloured_main_3x
    icon_coloured.url(:main_3x) if icon_coloured_file_name
  end

  def photo_main
    photo.url(:main) if photo_file_name
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
