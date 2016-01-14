class PrivateFile < ActiveRecord::Base
  extend Enumerize
  CATEGORIES = {
    :contract => %w(contract_scan contract),
    :place => %w(brief)
  }

  belongs_to :fileable, :polymorphic => true

  has_attached_file :attachment,
    :path => ":rails_root/storage/:class/:attachment/:id/:style/:basename.:extension"

  enumerize :category, :in => CATEGORIES.values.flatten

  validates_presence_of :name, :attachment
  validates_attachment_content_type :attachment, :content_type => ['text/plain', 'application/pdf', 'application/msword', "application/vnd.ms-excel", 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']

end
