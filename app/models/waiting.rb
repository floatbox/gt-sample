class Waiting < ActiveRecord::Base
  include PhoneNormalizer
  
  belongs_to :place
  belongs_to :room
  belongs_to :booking

  validates_presence_of :place, :persons, :time
  # добавить в будущем к валидации(убрал при разделени логики с booking) :name, :phone
  
  before_validation_on_create :set_defaults
  before_validation :change_booking_date, :if => :time_changed?
  after_save   :change_profile, :if => :phone_changed?
  
  named_scope :active, :conditions => 'cancelled_at is null and completed_at is null'
  named_scope :cancelled, :conditions => 'cancelled_at is not null'
  named_scope :completed, :conditions => 'completed_at is not null'
  named_scope :for_date, lambda { |date| { :conditions => ['booking_date = ?', date] }}
  named_scope :by_phone, lambda { |phone| { :conditions => ['phone = ?', phone] }}
  
  def profile
    place.profiles.by_phone(phone.to_s).first
  end
  
  def complete(booking)
    self.completed_at = Time.zone.now
    self.booking = booking
    self.save
  end
  
  def cancel
    update_attribute(:cancelled_at, Time.zone.now)
  end
  
private

  def set_defaults
    self.booking_date = place.get_booking_date(time) if time
    normalize_phone!
  end
  
  def change_booking_date
    self.booking_date = place.get_booking_date(time) if time
  end
  
  def change_profile
    if profile
      profile.update_attribute(:name, name) if profile.name.nil? and name
    elsif phone
      Profile.create do |p|
        p.place = place
        p.phone = phone
        p.name = name
      end
    end
  end
  
end