# In truth it' opposite of Availability
class Availability < ActiveRecord::Base
  include AssociationsPlaceReindex
  extend Enumerize

  KINDS = %w(corporate waiting_list)

  belongs_to :timetable

  enumerize :kind, :in => KINDS, :predicates => true

  validates_presence_of :timetable_id, :date, :time_from, :time_to
  validates_inclusion_of :kind, :in => KINDS

  named_scope :date, lambda {|date| { :conditions => ['date = ?', date] }}
  named_scope :time, lambda {|time| { :conditions => ['time_from <= ? and time_to >= ?', time, time] }}
  named_scope :kind, lambda {|kind| { :conditions => ['kind = ?', kind] }}

  before_validation_on_create :set_defaults

  def corporate?
    kind.to_s == 'corporate'
  end

  def waiting_list?
    kind.to_s == 'waiting_list'
  end

  def self.priority_kind(arr)
    if arr.include? 'corporate'
      'corporate'
    elsif arr.include? 'waiting_list'
      'waiting_list'
    else
      'active'
    end
  end

  def place(hash = {})
    timetable.place(hash)
  end

private

  def set_defaults
    if timetable && date
      period = timetable.booking_period_for_date(date)
      if corporate? || waiting_list?
        self.time_from = period.first
        self.time_to = period.last
      end
    end
  end

end
