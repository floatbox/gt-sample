class ApiUser < ActiveRecord::Base
  devise :database_authenticatable, :recoverable, :rememberable, :trackable,
    :encryptable, :authentication_keys => [:login], :encryptor => :old_sha1

  attr_accessible :email, :phone, :login, :password, :password_confirmation, :reset_password_token

  belongs_to :place
  has_many :tokens, :as => :item

  validates_presence_of :token, :login, :place_id
  validates_presence_of :password, :if => :password_required?
  validates_length_of :token, :is => 40
  validates_length_of :login, :minimum => 3
  validates_uniqueness_of :login, :token, :place_id
  validates_uniqueness_of :email, :allow_blank => true
  validates_presence_of :sms_login, :sms_sender, :if => :sms_mailer

  before_validation :nil_if_blank
  before_validation_on_create :generate_api_token

  def bookings
    place.bookings
  end

private

  def password_required?
    id.blank? || !password.nil? || !password_confirmation.nil?
  end

  def generate_api_token
    self.token = GenerateToken.random 40
  end

  def nil_if_blank
    self.password = nil if password.blank? # password is virtual attr
    self.password_confirmation = nil if password_confirmation.blank?
  end

end
