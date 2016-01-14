class Review < ActiveRecord::Base
  extend Enumerize
  include ReviewPresenter

  IMPRESSIONS = %w(like dislike didnotgo)

  enumerize :impression, in: IMPRESSIONS, predicates: true
  delegate :name, to: :booking, allow_nil: true

  belongs_to :booking
  belongs_to :phone_number, foreign_key: :phone, counter_cache: true
  belongs_to :place
  belongs_to :responsible, class_name: 'User'

  validates :place, :booking, :phone, presence: true
  validates :impression, inclusion: { in: IMPRESSIONS }

  before_validation :set_defaults, on: :create

  scope :sorted, ->(review_id = nil) { order(review_id.present? ? "(id = #{review_id.to_i}) DESC, created_at DESC" : 'created_at DESC') }
  scope :by_phone,   ->(phone) { where(phone: phone) }
  scope :moderated,         -> { where(moderated: true) }
  scope :negative,          -> { where(impression: 'dislike') }
  scope :positive,          -> { where(impression: 'like') }
  scope :visited,           -> { where.not(impression: 'didnotgo') }
  scope :for_public,        -> { moderated.visited.with_description }
  scope :with_description,  -> { where("description IS NOT NULL AND description != ''") }
  scope :production,        -> { moderated.visited.with_description }
  named_scope :bub_sorted, lambda { |review_id| { :order => review_id.present? ? "(id = #{review_id.to_i}) DESC, created_at DESC" : 'created_at desc' } }

  private

  def set_defaults
    self.place_id = booking.try(:place_id)
    self.phone = booking.try(:phone)
  end
end
