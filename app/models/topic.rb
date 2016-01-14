class Topic < ActiveRecord::Base

  acts_as_list

  belongs_to :city
  has_many :answers

  has_attached_file :photo, { styles: { feed_2x: ['718x320', 'jpg'],
                                        feed_3x: ['1194x480', 'jpg'],
                                        topic_2x: ['750x464#', 'jpg'],
                                        topic_3x: ['1242x696#', 'jpg'] },
                              convert_options: { feed_2x: "-quality 70",
                                                 feed_3x: "-quality 70",
                                                 topic_2x: "-quality 70",
                                                 topic_3x: "-quality 70" },
                              path: "topics/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates :photo, attachment_presence: true
  validates_attachment_content_type :photo, content_type: /\Aimage\/.*\Z/

  validates :question, :city, presence: true

  scope :sorted, -> { order(:position) }

  def can_answer_by?(user)
    answers.where(user_id: user.id).count == 0
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
