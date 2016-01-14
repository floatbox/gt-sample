class PlaceFeature < ActiveRecord::Base
  include AssociationsPlaceReindex

  belongs_to :feature, inverse_of: :place_features
  belongs_to :place, inverse_of: :place_features

  delegate :title, :specialization, :parent_id, :kind, to: :feature

  validates_presence_of :place, :feature, :weight
  validates_uniqueness_of :feature_id, scope: :place_id

  validate :check_only_one_main_feature

  scope :with_text, -> { where('text is not null and text != ?', '') }

  after_destroy :delete_children

  delegate :title, :specialization,
    :to => :feature, :prefix => true, :allow_nil => true

  def label
    (title + ' ' + text.to_s).trim
  end

  private

  def delete_children
    PlaceFeature.destroy_all(place_id: place_id, feature_id: feature.children.pluck(:id))
  end

  def check_only_one_main_feature
    if main && place.specializations.size > 1
      errors.add(:main, 'у заведения может быть только одна главная особенность')
    end
  end
end
