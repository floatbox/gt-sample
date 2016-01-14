class BookingRevise < ActiveRecord::Base
  extend Enumerize

  COMMON_STATUSES = %w(overdue confirm)

  STATUSES_HASH = {
    overdue: 'Гость не пришел',
    confirm: 'Подтверждено'
  }

  enumerize :place_status, in: COMMON_STATUSES, predicates: { prefix: true }
  enumerize :guest_status, in: COMMON_STATUSES, predicates: { prefix: true }
  enumerize :final_status, in: COMMON_STATUSES, predicates: { prefix: true }

  belongs_to :booking, inverse_of: :booking_revise
  belongs_to :place_employee, :class_name => 'Employee'
  belongs_to :final_employee, :class_name => 'Employee'
  belongs_to :sum_employee, :class_name => 'Employee'
  belongs_to :place_responsible, :class_name => 'User'
  belongs_to :guest_responsible, :class_name => 'User'
  belongs_to :final_responsible, :class_name => 'User'
  belongs_to :sum_responsible, :class_name => 'User'

  before_validation :resolve_sum_logic
  before_validation :resolve_final_logic

  validate do
    check_place_employee
  end

  validates :booking, presence: true
  validates :place_status, :place_employee_id, presence: true, :if => lambda { |br| br.place_status_at_changed? }
  validates :guest_status, presence: true, :if => lambda { |br| br.guest_status_at_changed? }
  validates :final_status, :final_employee_id, presence: true, :if => lambda { |br| br.final_status_at_changed? || br.hold }
  validates :place_sum, :sum_employee_id, presence: true, :if => lambda { |br| br.final_status_at_changed? && br.final_status_confirm? }

  before_save :set_guest_status_and_notify, :if => lambda { |br| br.guest_source == 'gettable-iphone' }
  after_save :check_place_status, :if => :place_status_at_changed?
  after_save :check_guest_status, :if => :guest_status_at_changed?
  after_save :check_final_status, :if => :final_status_at_changed?
  after_save :check_hold_final_status, :if => :hold_changed?

  def place_status_str
    STATUSES_HASH[place_status.to_sym] if place_status
  end

  def guest_status_str
    STATUSES_HASH[guest_status.to_sym] if guest_status
  end

  def final_status_str
    STATUSES_HASH[final_status.to_sym] if final_status
  end

  def place_employee_name
    place_employee.name_with_position if place_employee
  end

  def final_employee_name
    final_employee.name_with_position if final_employee
  end

  private

  def check_place_employee
    if place_employee
      unless place_employee.place.id == booking.place.id
        errors.add(:base, "Сотрудник должен принадлежать к тому же заведению")
      end
    end
  end

  def check_place_status
    booking.revise_confirm! if place_status_confirm?
  end

  def check_guest_status
    if place_status_overdue? && guest_status_overdue?
      booking.set_fake
      set_checked_fields(true)
    end
  end

  def check_final_status
    if final_status_confirm?
      booking.revise_confirm!
      update_booking
    elsif final_status_overdue?
      booking.set_fake
      set_checked_fields(true)
    end
  end

  def check_hold_final_status
    if hold? && final_status_confirm?
      booking.revise_confirm!
      set_booking_reconciliation_employee(true)
    end
  end

  def resolve_sum_logic
    if place_sum && sum_employee.blank?

      if place_employee_id && place_status_confirm?
        self.sum_employee_id = place_employee_id
      end

      if final_employee_id && final_status_confirm?
        self.sum_employee_id = final_employee_id
      end

    end
  end

  def resolve_final_logic
    if place_employee_id && place_status_confirm?
      self.final_employee_id = place_employee_id
      self.final_status = place_status
    end
  end

  def update_booking
    persons = place_persons ? place_persons : booking.persons
    booking.update(persons: persons) unless persons == booking.persons

    set_booking_revenue
    set_checked_fields(false)

    booking.save
  end

  def set_booking_revenue
    revenue = case booking.revenue_type
    when 'table', 'person', 'monthly_bill', 'monthly_pay'
      place_sum
    when 'price_percent'
      booking.revenue_sum * place_sum
    end

    booking.revenue = revenue
  end

  def set_checked_fields(save_booking)
    booking.checked_at = true
    set_booking_reconciliation_employee(save_booking)
  end

  def set_booking_reconciliation_employee(save_booking)
    booking.reconciliation_employee_id = get_booking_employee_id
    booking.save if save_booking
  end

  def get_booking_employee_id
    sum_employee_id || final_employee_id || place_employee_id
  end

  def set_guest_status_and_notify
    self.guest_status_at = Time.zone.now

    FinancialNotifier.delay.report_adout_guest_revise(self, booking)
  end

end
