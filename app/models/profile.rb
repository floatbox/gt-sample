class Profile < ActiveRecord::Base
  include PhoneNormalizer
  
  attr_accessible :complicated, :good_tips, :vip, :good_fc_dc, :description
  
  belongs_to :user
  belongs_to :place
  
  validates_presence_of :place, :phone
  validates_uniqueness_of :phone, :scope => :place_id
  
  before_validation_on_create :normalize_data!
  
  named_scope :place, lambda {|place| { :conditions => ['place_id = ?', place.to_i] }}
  named_scope :by_phone, lambda {|phone| { :conditions => ['phone = ?', phone] }}
  named_scope :with_visits, :conditions => 'visits > 0'
  named_scope :dont_spam, :conditions => ['last_delivery_at is null or last_delivery_at < ?', 1.day.ago]
  
  def bookings
    place.bookings.by_phone(phone)
  end
  
  def waitings
    place.waitings.by_phone(phone)
  end
  
  def last_visit_in_days
    last_visit ? (Time.zone.now.to_date - last_visit).to_i : 0
  end
  
  def last_delivery_in_days
    last_delivery_at ? (Time.zone.now.to_date - last_delivery_at.to_date).to_i : 0
  end
  
  def confirmed?
    (last_confirmed_at.present? and last_confirmed_at > 1.day.ago) or confirmations > 2
  end
  
  def filtered_phone
    length = phone.length
    phone[0...length - 4] + ('*' * 4) if length > 4
  end
  
  attr_accessor :guests
  def guests
    (avg_persons * visits).round
  end
  
  class << self
    def search text
      cond = []
      [:name, :phone].each do |field|
        cond << ["profiles.#{field} ILIKE ?", "%#{text}%"]
      end

      result = [cond.map { |q, p| q }.join(' OR ')]
      cond.map { |q, p| result << p }
      scoped :conditions => result.flatten
    end
  end
  
private
  
  def normalize_data!
    normalize_phone!
    self.name = (name.slice(0,1).capitalize + name.slice(1..-1)) if name.present?
  end
  
end
