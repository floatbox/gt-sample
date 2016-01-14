class Avatar < ActiveRecord::Base
  extend Enumerize

  KINDS = ['base', 'badge']
  ACHIEVEMENT_TYPE = [ 'feature', 'network', 'login', 'booking' ]

  enumerize :kind, :in => KINDS, :predicates => true
  enumerize :achievement_type, :in => ACHIEVEMENT_TYPE, :predicates => true

  has_attached_file :image, { styles: {
                                show:    ['80x80#',   'png'],
                                show_2x: ['160x160#', 'png'],
                                show_3x: ['240x240#', 'png'],
                                preview_2x: ['320x320#', 'png'],
                                preview_3x: ['480x480#', 'png'] },
                      path: 'avatars/:id/image/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)
  has_attached_file :image_gray, { styles: {
                                show:    ['80x80#',   'png'],
                                show_2x: ['160x160#', 'png'],
                                show_3x: ['240x240#', 'png'],
                                preview_2x: ['320x320#', 'png'],
                                preview_3x: ['480x480#', 'png'] },
                      path: 'avatars/:id/image_gray/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_attachment_content_type :image, content_type: ['image/png'], allow_blank: true
  validates_attachment_content_type :image_gray, content_type: ['image/png'], allow_blank: true

  has_many :user_avatars

  validates :title, presence: true

  scope :base, -> { where(kind: 'base') }
  scope :badge, -> { where(kind: 'badge') }
  scope :feature_achievement, -> { where(achievement_type: 'feature') }
  scope :network_achievement, -> { where(achievement_type: 'network') }
  scope :login_achievement, -> { where(achievement_type: 'login') }
  scope :booking_achievement, -> { where(achievement_type: 'booking') }

  def image_show_2x
    image.url(:show_2x) if image_file_name
  end

  def image_show_3x
    image.url(:show_3x) if image_file_name
  end

  def image_preview_2x
    image.url(:preview_2x) if image_file_name
  end

  def image_preview_3x
    image.url(:preview_3x) if image_file_name
  end

  def image_gray_show_2x
    image_gray.url(:show_2x) if image_gray_file_name
  end

  def image_gray_show_3x
    image_gray.url(:show_3x) if image_gray_file_name
  end

  def image_gray_preview_2x
    image_gray.url(:preview_2x) if image_gray_file_name
  end

  def image_gray_preview_3x
    image_gray.url(:preview_3x) if image_gray_file_name
  end

end
