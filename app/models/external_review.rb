class ExternalReview < ActiveRecord::Base
  extend Enumerize

  enumerize :source, in: %w( zoon afisha foursquare ) , predicates: true

  belongs_to :place

  validates_presence_of :place, :text, :url, :ext_review_id, :author_name
  validates_presence_of :rate, :rate_pic, :if => :afisha?

  scope :sorted, -> { order(created_at: :desc) }
  scope :limited, -> { limit(10) }
  scope :good_rate, -> { where('rate >= ?', 3) }
  scope :show, -> { where(show: true) }
  scope :afisha, -> { where(source: 'afisha') }
  scope :zoon, -> { where(source: 'zoon') }
  scope :foursquare, -> { where(source: 'foursquare') }

end