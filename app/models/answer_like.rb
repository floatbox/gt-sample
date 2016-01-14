class AnswerLike < ActiveRecord::Base

  belongs_to :user
  belongs_to :answer, counter_cache: :likes_count

  validates :user, :answer, presence: true
  validates :user_id, uniqueness: { scope: :answer_id }

end
