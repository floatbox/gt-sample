# Вспомогательный класс для сбора инфы по номеру телефона, упрощения сбора статы, также он нужен
# для взаимодействия с сущностью Profile.
# Если у номера стоит call_center: true - этот номер нашего колл-центра, мы по ним деаем выборки и смотрим стату по звонкам/броням.

class PhoneNumber < ActiveRecord::Base
  include PhoneNormalizer
  set_primary_key "phone"
  self.primary_key = :phone

  belongs_to :user

  validates_presence_of :phone
  validates_uniqueness_of :phone

  # associations for classic PhoneNumber, not call_center
  has_many :bookings, :foreign_key => :phone
  has_many :reviews, :foreign_key => :phone
  has_many :smses, -> { sorted }, foreign_key: :phone, class_name: 'Sms::Sms'

  before_validation_on_create :normalize_data!

  named_scope :online_booking_between, lambda { |t1, t2| { :conditions => ['first_online_booking >= ? and first_online_booking < ?', t1.utc, t2.utc] }}
  named_scope :online_booking_before, lambda { |t| { :conditions => ['first_online_booking < ?', t.utc] }}
  named_scope :call_center, :conditions => 'call_center = true'

  named_scope :google_channel, :conditions => ['call_center_purpose like ?', '%ctx.google%']
  named_scope :yandex_channel, :conditions => ['call_center_purpose like ?', '%ctx.yandex%']

  def profiles
    Profile.by_phone(phone)
  end

  def confirmed?
    (last_confirmed_at.present? and last_confirmed_at > 1.day.ago) or confirmations >= 1
  end

  def has_negative_review?
    reviews.negative.exists?
  end

  def set_confirmed
    PhoneNumber.transaction do
      self.confirmations += 1
      self.last_confirmed_at = Time.zone.now
      self.save
    end
  end

  def self.channel_phones(channel)
    unless Rails.env.test?
      PhoneNumber.send("#{channel}_channel").pluck(:phone)
    end
  end

private

  def normalize_data!
    normalize_phone!
    self.name = (name.slice(0,1).capitalize + name.slice(1..-1)) if name.present?
  end

end
