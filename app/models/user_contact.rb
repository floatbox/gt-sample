class UserContact < ActiveRecord::Base
  extend Enumerize

  enumerize :source, in: %w(address_book facebook)

  belongs_to :user
  belongs_to :contact_user, class_name: 'User'

  validates :name, :source, :value, :user, presence: true
  validates :value, uniqueness: { scope: :user_id }

  before_save :link_existed_user
  scope :linked, -> { where.not(contact_user_id: nil) }
  scope :phones, -> { where(source: 'address_book') }

  def link_existed_user
    if link_user = User.where(phone: value).take
      self.contact_user = link_user
    end
  end

end

class UserContactAdressBookParser
  include PhoneNormalizer

  def self.parse(collection, controller)
    collection.map do |item|
      item[:phones].map do |phone|
        { value: normalized_phone(phone),
          name: item[:name],
          source: :address_book,
          user: controller.current_user }
      end.flatten
    end
  end
end
