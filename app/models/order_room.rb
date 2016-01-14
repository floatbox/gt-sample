class OrderRoom < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include AssociationsPlaceReindex

  BANQUET_FIELDS = %w( max_persons person_payment service_fee deposit_sum )

  belongs_to :place
  has_many :tables
  has_many :bookings

  validates_presence_of :place
  validates_presence_of :title

  validates_numericality_of :person_payment, :greater_than_or_equal_to => 1, :allow_blank => true
  validates_numericality_of :service_fee, :less_than_or_equal_to => 1, :allow_blank => true
  validates_numericality_of :deposit_sum, :greater_than_or_equal_to => 1, :allow_blank => true
  validates_numericality_of :max_persons, :greater_than_or_equal_to => 1, :allow_blank => true

  before_save :renew_banquet_updated_at, :if => lambda{ |p| BANQUET_FIELDS.map{ |f| p.send("#{f}_changed?") }.include?(true) }
  before_destroy :can_destroy?

  named_scope :sorted, :order => 'position asc'

  def banquet_cost
    cost = []
    cost << deposit_sum if deposit_sum
    cost << "#{person_payment}/чел" if person_payment
    cost << "#{(service_fee * 100).to_i}%" if service_fee

    cost.join(' + ')
  end

  def can_destroy?
    return false if tables.count > 0 || bookings.count > 0
  end

  def full_description
    "#{title} – #{max_persons} чел. = #{banquet_cost}"
  end

  def avaliable_table(date, persons)
    # надо переделать в нормальный вид
    tables.opened.each{ |t| (@res = t and break) if t.avaliable_on?(date) and t.enough_space?(persons) }
    tables.opened.each{ |t| (@res = t and break) if t.avaliable_on?(date) } unless @res
    @res || tables.opened.for_persons(persons).first || tables.opened.first
  end

  def opened?
    place.call_center? ? true : tables.opened.count > 0
  end

  def price_explained
    if person_payment?
      "#{number_to_currency(person_payment, :precision => 0)}/чел."
    elsif deposit_sum?
      "#{number_to_currency(deposit_sum, :precision => 0)}/зал."
    end
  end

  def calculate_price(persons)
    if person_payment?
      person_payment * persons
    elsif deposit_sum?
      deposit_sum
    end
  end

private

  def renew_banquet_updated_at
    place.update_attribute(:banquet_updated_at, Time.zone.now)
  end

end
