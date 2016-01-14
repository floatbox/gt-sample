class Reviewer < ActiveRecord::Base

  has_attached_file :avatar,
                    { styles: { place: ['64x64#', 'png'] },
                      path: 'reviewers/:id/avatars/:style.png'
                    }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_many :quotes

  validates :name, :position, presence: true

  validates_attachment_presence :avatar
  validates_attachment_content_type :avatar, content_type: /image/
end
