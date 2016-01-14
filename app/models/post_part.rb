class PostPart < ActiveRecord::Base
  extend Enumerize

  has_attached_file :photo, {
    :styles => {
      :big => ['740x330#', 'jpg'],
    },
    :path => "blog/posts/:post_id/photos/:id/:style.jpg"
  }.merge(PAPERCLIP_STORAGE_OPTIONS)

  belongs_to :post
  enumerize :kind, :in => %w(paragraph cite figure)

  acts_as_list :scope => :post

  validates_attachment_content_type :photo, :content_type => /image/, :allow_blank => true

end
