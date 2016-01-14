class FriendNotification < ActiveRecord::Base
  include PhoneNormalizer

  MAX_FRIEND_NOTIFICATIONS = 8

  belongs_to :booking
  belongs_to :user

  has_many :smses, :class_name => 'Sms::Sms'

  validates_presence_of :booking, :user
  validates_presence_of :phone, :message #, :name
  validates_uniqueness_of :phone, :scope => :booking_id

  validate_on_create    :dont_spam
  validate_on_create    :user_owns_booking
  validate_on_create    :booking_into_future # позднее заменить нижним валидатором
  # validate_on_create    :booking_active? - добавить валидатор чтобы не рассылали инфу
  #                       по прошедшим броням(как только приведутся в норму состояния у броней)

  before_validation_on_create :set_defaults
  after_create :create_confirmation_sms # for case when booking already confirmed

  def create_confirmation_sms
    if smses.with_callback(['friend_wish_sms']).count == 0 && booking.smses.without_friends.with_callback(['gettable_wish_sms', 'promo_sms']).count == 1

      smses.create!(
        :phone => phone,
        :message => message,
        :booking => booking,
        :callback_method => 'friend_wish_sms'
      )
    end
  end

private

  def set_defaults
    self.message = booking.friend_notification_message

    normalize_phone!
  end

  def user_owns_booking
    if booking and booking.user_id != user_id
      errors.add :booking_id, "Нельзя создавать уведомления для чужих броней"
    end
  end

  def dont_spam
    if booking.friend_notifications.count > MAX_FRIEND_NOTIFICATIONS
      errors.add :phone, "Максимальное кол-во людей в рассылке: #{MAX_FRIEND_NOTIFICATIONS}"
    end
  end

  def booking_into_future
    if booking and booking.time < Time.zone.now
      errors.add(:booking_id, "Нельзя оповещать друзей о прошедших бронях")
    end
  end

end