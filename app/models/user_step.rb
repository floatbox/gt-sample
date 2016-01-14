class UserStep < ActiveRecord::Base

  KINDS = [ 'booking', 'referral_booking', 'start', 'loyalty', 'promo_code', 'place_promo', 'gettable', 'ny2015']

  belongs_to :user
  belongs_to :reason, :polymorphic => true

  validates :user, :amount, presence: true
  validates :reason_type, :reason_id, presence: true, :if => lambda { |us| us.kind == 'booking' }

  before_validation :set_defaults, on: :create

  scope :sorted, -> { order(:created_at) }
  scope :booking, -> { where(kind: 'booking') }


  def description
    case kind
    when 'booking'
      if reason.is_a?(Booking)
        {
          text: reason.place.title,
          comment: reason.nice_time + ', ' + reason.stringify_persons
        }
      end
    when 'referral_booking'
      if reason.is_a?(Booking)
        {
          text: 'Ваш друг ' + reason.name + ' сделал первое бронирование на Gettable',
        }
      end
    when 'ny2015'
      {
          text: 'Балл в подарок на Новый Год 🎄',
      }
    else
      {
        text: 'Ура, вы начали пользоваться Gettable!',
      }
    end
  end

  def place
    if reason.is_a?(Booking)
      reason.place
    end
  end

  private

  def set_defaults
    self.kind ||= 'booking'
    self.amount ||= 1
  end

end
