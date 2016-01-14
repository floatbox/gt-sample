class Quote < ActiveRecord::Base
  extend Enumerize

  default_scope { order(created_at: :asc) }

  acts_as_list scope: :place, top_of_list: 0

  delegate :avatar, :name, :position, to: :reviewer, prefix: true

  belongs_to :reviewer
  belongs_to :place

  validates :place, presence: true

  def author?
    reviewer_id?
  end
end
