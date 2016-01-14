require 'image_size'

class Gallery < ActiveRecord::Base
  extend Enumerize

  acts_as_list scope: :place, top_of_list: 0

  belongs_to :place

  has_many :place_photos, dependent: :destroy

  attr_accessor :multiloader_url
  enumerize :kind, in: %w(main winter terrace people food menu_scan party employees instagram), predicates: true

  validates_presence_of :name
  validate :photo_presence

  scope :visible, -> { where(visible: true) }
  scope :landing, -> { where(landing: true) }
  scope :sorted,  -> { order(position: :asc) }
  scope :instagram, -> { where(kind: 'instagram')
                          .where('place_photos_count >= 1')
                          .includes(:place_photos)
                          .includes(:place)
                          .order(:id) }

  before_save :set_height_to_photo,   if: ->(g) { g.visible_changed? and g.visible }
  before_save :update_landing_photos, if: ->(g) { g.main? && (g.visible_changed? || g.landing_changed?) }

  before_destroy :check_can_be_deleted

  def active?
    visible && landing
  end

  def can_be_deleted?
    place_photos.count.zero?
  end

private

  def photo_presence
    errors.add(:visible, 'Нельзя сделать видимой галерею без фото') if visible and place_photos.count.zero?
  end

  def check_can_be_deleted
    return true if can_be_deleted?

    errors.add(:base, 'Нельзя удалить галерею с фото')
    false
  end

  def set_height_to_photo
    place_photos.find_each do |pp|
      open(pp.photo.url(:original), "rb") do |fh|
        size = ImageSize.new(fh.read).get_size
        pp.original_height = size.try(:last).to_i
        pp.original_width = size.try(:first).to_i
      end

      open(pp.photo.url(:gallery), "rb") do |fh|
        pp.height = ImageSize.new(fh.read).get_size.try(:last).to_i
      end

      pp.save
    end
  end

  def update_landing_photos
    place_photos.find_each do |pp|
      pp.update_attribute(:main_landing, active?)
    end
  end

end
