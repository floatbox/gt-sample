class PdfMenu < ActiveRecord::Base

  acts_as_list scope: :place, top_of_list: 0

  belongs_to :place, inverse_of: :pdf_menus

  has_attached_file :pdf_file, { :path => "pdf_menus/:id/menu.pdf" }.merge(PAPERCLIP_STORAGE_OPTIONS)
  validates_attachment_content_type :pdf_file, :content_type => ['application/pdf']

  validates_attachment :pdf_file, presence: true,
    content_type: { content_type: 'application/pdf' },
    size: { in: 0..15.megabytes }

  scope :visible, -> { where(visible: true) }

  delegate :title, to: :place, prefix: true, allow_nil: true

  def pdf_file_url
    pdf_file.url if pdf_file_file_name
  end

end
