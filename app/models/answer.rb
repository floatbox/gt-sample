class Answer < ActiveRecord::Base

  belongs_to :topic
  belongs_to :user

  has_many :answer_likes

  validates :topic, :user, :text, presence: true
  # закомментил для тестирования
  # validates :user_id, uniqueness: { scope: :topic_id }
  validate :user_not_spamer

  scope :sorted, -> { order(likes_count: :desc) }

  delegate :question, to: :topic, prefix: true, allow_nil: true

  def liked_by?(user)
    answer_likes.where(user_id: user.id).count > 0
  end

private

  def user_not_spamer
    return if user.role.present?
    if user.answers.where('created_at >= ?', 1.day.ago.utc).count > 10
      errors.add(:user_id, "Мы ограничили кол-во комментариев в 10 штук за день")
    end
  end

end
