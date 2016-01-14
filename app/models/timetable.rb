# open_time, close_time - время границ работы букинга для опереденного дня
# open_at, close_at - время границ работы заведения для опереденного дня

class Timetable < ActiveRecord::Base
  extend Enumerize
  include TimetablePresenter
  include AssociationsPlaceReindex

  TIME_ATTRS = [ %w(sun_open_time sun_close_time), %w(mon_open_time mon_close_time),
                 %w(tue_open_time tue_close_time), %w(wed_open_time wed_close_time),
                 %w(thu_open_time thu_close_time), %w(fri_open_time fri_close_time),
                 %w(sat_open_time sat_close_time) ]
  ALL_TIME_ATTRS = [ %w(sun_open_time sun_close_time), %w(mon_open_time mon_close_time),
                 %w(tue_open_time tue_close_time), %w(wed_open_time wed_close_time),
                 %w(thu_open_time thu_close_time), %w(fri_open_time fri_close_time),
                 %w(sat_open_time sat_close_time),
                 %w(sun_open_at sun_close_at), %w(mon_open_at mon_close_at),
                 %w(tue_open_at tue_close_at), %w(wed_open_at wed_close_at),
                 %w(thu_open_at thu_close_at), %w(fri_open_at fri_close_at),
                 %w(sat_open_at sat_close_at) ]
  WORKING_DAYS = %w(sun mon tue wed thu fri sat)

  # при создании бара по умолчанию создается timtable с временем бронирования с 17.00 до 02.00
  # разобраться с timezone
  TIME_DEFAULTS = [Date.new(2014,9,1) + 17.hours, Date.new(2014,9,1) + 3.hours]
  BOOKING_HOLIDAYS = [Date.new(2014,3,8)]
  DELTA = 90

  enumerize :lunch_type, :in => %w(discount special_menu no)

  belongs_to :place

  has_many :availabilities

  validates_presence_of :place_id
  validates_uniqueness_of :place_id
  validate :time_correspond_to_timenet
  validate :times_is_not_equal
  validate :lunch_is_correct, :if => lambda{ |t| t.lunch_from and t.lunch_to }
  validate :deposit_is_correct
  validates_inclusion_of :lunch_type, :in => %w( discount special_menu  no ), :allow_blank => true
  validates_inclusion_of :day_off_kind, :in => %w( day_off no_reserve ), :allow_blank => true

  before_validation :set_as_nils
  before_validation_on_create :set_defaults

  # работает ли в этот день заведение?
  def working_day?(date = nil)
    date ||= current_time_zone.now

    !day_off?(date) && available_on?(date)
  end

  # работает ли сегодня заведение?
  def working_today?
    working_day? booking_date_for_time(current_time_zone.now)
  end

  # скоуп date(...) опасный - т.к. внутрь передается время, могут быть косяки с этим(таймзона например)
  def available_on?(date)
    availabilities.date(date).kind('corporate').count == 0 and !ny_offline_day?
  end

  # метод для отображения состояния отключенного коллцентра на НГ
  def ny_offline_day?
    DateTime.new(2015, 12, 31, 19) <= current_time_zone.now and current_time_zone.now <= DateTime.new(2016, 1, 1, 11)
  end

  # будний ли день(учитывая праздники)
  def weekday?(date)
    !BOOKING_HOLIDAYS.include?(date) && (1..5).include?(date.wday)
  end

  # выходной день ресторана!
  def day_off?(date)
    !self[WORKING_DAYS[date.wday]]
  end

  def date_closed?(date)
    !working_day?(date) or place_overflow?(date)
  end

  def place_overflow?(date)
    if place.platform?
      place.available_table(date).nil?
    else
      false
    end
  end

  def has_working_time?
    res = WORKING_DAYS.map do |w_day|
      self["#{w_day}_around_the_clock"] || (self["#{w_day}_open_at"].present? and (self["#{w_day}_close_at"].present? or self["#{w_day}_last_client"]))
    end.uniq

    res.count == 1 and res.first
  end

  def wday_to_rus(i)
    i == 0 ? 6 : i - 1
  end

  def wday_to_eu(i)
    i == 6 ? 0 : i + 1
  end

  def booking_period_for_date(date)
    extraday = time_to(date) <= time_from(date) ? 1 : 0
    [make_datetime(date, time_from(date)), make_datetime(date + extraday.day, time_to(date))]
  end

  def lunch(date)
    lunch_from && lunch_to ? [make_datetime(date, lunch_from), make_datetime(date, lunch_to)] : []
  end

  def can_book_on_time?(date, time)
    can_book = true

    if weekday? date
      if !lunch_booking? && lunch(date).present?
        can_book = (time < lunch(date).first or time >= lunch(date).last)
      end
    end

    can_book
  end

  # еще раз проверить логику здесь
  def booking_date_for_time(t)
    t = t.in_time_zone
    date = t.to_date
    previous_period = booking_period_for_date(date.yesterday)
    current_period = booking_period_for_date(date)
    future_period = booking_period_for_date(date.tomorrow)

    if t < previous_period.last + DELTA.minutes
      date.yesterday
    elsif t < current_period.last + DELTA.minutes
      date
    else
      date.tomorrow
    end
  end

  def nearest_booking_time(date, ipad = true, delta = 0)
    result = nil
    booking_timenet(date, ipad).each do |time|
      if time >= (current_time_zone.now + delta.minutes) and result.nil?
        result = time and break
      end
    end

    result
  end

  def booking_timenet(date, ipad = true, current_time = nil)
    result = []

    if working_day?(date) or ipad
      current_time = booking_period_for_date(date).first unless current_time
      booking_to = booking_period_for_date(date).last

      while current_time <= booking_to
        result << current_time
        current_time += Booking::TIMENET.minutes
      end
    end

    result
  end

  # используется для сетки времени в виджетах и в приложении iPhone
  def timenet_with_states(date, current_time = nil, phone = false)
    result = []

    if place.active? and !date_closed?(date)
      current_time = booking_period_for_date(date).first unless current_time
      booking_to = booking_period_for_date(date).last

      while current_time <= booking_to
        if can_book_on_time?(date, current_time)
          result << state_for_time(date, current_time, phone)
        end
        current_time += Booking::TIMENET.minutes
      end
    end

    result
  end

  def deposit?
    WORKING_DAYS.any?{ |day| self["#{day}_deposit_type"].present?  }
  end

  # Метод показывает, надо ли что-то платить перед посещением
  # Это может быть как депозит, так и оплата за вход
  def premoney?(date)
    deposit_day?(date) or !!entrance_sum(date)
  end

  def deposit_day?(date)
    (!!deposit_type(date) and !!deposit_sum(date)) or !!deposit_description(date)
  end

  def special_info_from(date)
    if premoney?(date)
      deposit_day?(date) ? deposit_from(date) : 1
    end
  end

  def weekday_working_time(wday)
    dname = WORKING_DAYS[wday]
    if !self[dname]
      nil
    elsif self["#{dname}_around_the_clock"]
      "круглосуточно"
    elsif self["#{dname}_last_client"] and self["#{dname}_open_at"].present?
      dfrom = make_datetime(Date.today, self["#{dname}_open_at"].in_time_zone)
      "с #{dfrom.strftime('%k:%M').strip} до последнего клиента"
    elsif self["#{dname}_close_at"].present? and self["#{dname}_open_at"].present?
      dfrom = make_datetime(Date.today, self["#{dname}_open_at"].in_time_zone)
      dto = make_datetime(Date.today, self["#{dname}_close_at"].in_time_zone)
      "#{dfrom.strftime('%k:%M').strip} – #{dto.strftime('%k:%M').strip}"
    else
      nil
    end
  end

  def today_until_working_time
    today_wday = current_time_zone.now.hour < 6 ? Date.yesterday.wday : Date.today.wday
    dname = WORKING_DAYS[today_wday]

    if !self[dname]
      nil
    elsif self["#{dname}_around_the_clock"]
      "Круглосуточно"
    elsif self["#{dname}_last_client"] and self["#{dname}_open_at"].present?
      dfrom = make_datetime(Date.today, self["#{dname}_open_at"].in_time_zone)
      "Сегодня работает до последнего клиента"
    elsif self["#{dname}_close_at"].present? and self["#{dname}_open_at"].present?
      dto = make_datetime(Date.today, self["#{dname}_close_at"].in_time_zone)
      "Сегодня работает до #{dto.strftime('%k:%M').strip}"
    else
      nil
    end
  end

  def es_weekday_working_time(dname)
    if !self[dname]
      nil
    elsif self["#{dname}_around_the_clock"]
      { :open => 6, :close => 30, :day => dname }
    elsif self["#{dname}_last_client"] && self["#{dname}_open_time"].present?
      dfrom = make_datetime(Date.today, self["#{dname}_open_time"].in_time_zone)
      dfrom = time_to_float(dfrom)
      dfrom = dfrom + 24 if dfrom <= 6
      { :open => dfrom, :close => 24, :day => dname }
    elsif self["#{dname}_close_time"].present? && self["#{dname}_open_time"].present?
      dfrom = make_datetime(Date.today, self["#{dname}_open_time"].in_time_zone)
      dfrom = time_to_float(dfrom)
      dto = make_datetime(Date.today, self["#{dname}_close_time"].in_time_zone)
      dto = time_to_float(dto)
      dto = dto + 24 if dto < 6
      { :open => dfrom, :close => dto, :day => dname }
    end
  end

  def time_to_float(time)
    time.strftime('%k').to_f + time.strftime('%M').to_f / 60
  end

  def today_working_time(date = booking_date_for_time(current_time_zone.now))
    weekday_working_time(date.wday) || 'выходной'
  end

  def today_working_state(date = booking_date_for_time(current_time_zone.now))
    dname = WORKING_DAYS[date.wday]
    if !self[dname]
      '252,69,49,1'
    elsif self["#{dname}_around_the_clock"]
      '92,168,30,1'
    elsif self["#{dname}_last_client"] && self["#{dname}_open_at"].present?
      '92,168,30,1'
    elsif self["#{dname}_close_at"].present? && self["#{dname}_open_at"].present?
      dfrom = make_datetime(date, self["#{dname}_open_at"].in_time_zone)
      dto = make_datetime(date, self["#{dname}_close_at"].in_time_zone)
      dto += 1.day if dfrom >= dto # extraday analog
      if dfrom <= current_time_zone.now && current_time_zone.now <= dto
        '92,168,30,1'
      else
        '252,69,49,1'
      end
    else
      '252,69,49,1'
    end
  end

  def deposit_sum(date)
    self["#{WORKING_DAYS[date.wday]}_deposit_sum"]
  end

  def deposit_type(date)
    self["#{WORKING_DAYS[date.wday]}_deposit_type"]
  end

  def deposit_from(date)
    self["#{WORKING_DAYS[date.wday]}_deposit_from"]
  end

  def deposit_timefrom(date)
    t = self["#{WORKING_DAYS[date.wday]}_deposit_timefrom"]
    # convert t in timezone because use instantly value from class
    t ? make_datetime(date, t.in_time_zone) : nil
  end

  def deposit_description(date)
    self["#{WORKING_DAYS[date.wday]}_deposit_str"]
  end

  def entrance_sum(date)
    self["#{WORKING_DAYS[date.wday]}_entrance_sum"]
  end

  def entrance_description(date)
    self["#{WORKING_DAYS[date.wday]}_entrance_description"]
  end

  def booking_terms
    place.booking_features
  end

  def with_terms?
    booking_terms.count > 0
  end

  def special_info_type(date)
    if with_terms? or special_title.present?
      'terms'
    elsif premoney?(date)
      'deposit'
    end
  end

  def to_label
    'Расписание'
  end

  def make_booking_time(date, time)
    selected_time = time.split(':').map{|t| t.to_i}
    extraday = need_extraday?(date, selected_time) ? 1 : 0
    date += extraday.day

    current_time_zone.local(date.year, date.month, date.day, selected_time.first, selected_time.last)
  rescue TZInfo::AmbiguousTime => e
    current_time_zone.local(date.year, date.month, date.day, selected_time.first + 1, selected_time.last)
  end

  class << self

    def search_time
      now_hour = current_time_zone.now.hour
      (now_hour >= 22 or now_hour < 19) ? '19:00' : "#{current_time_zone.now.hour + 1}:00"
    end

    def search_date
      current_time_zone.now.hour >= 22 ? Date.tomorrow : Date.today
    end

    def next_week
      Date.today + (7 - Date.today.wday)
    end

    def cool_dates_array(date, kind, number_of_days = nil)
      quantity = case kind
        when 'common' then 14.days
        when 'iphone_app' then 30.days
        else 7.days
      end

      quantity = number_of_days.days if number_of_days

      arr = (date .. date + quantity).to_a
      holidays = BOOKING_HOLIDAYS.map do |bh|
        diff_in_days = bh - arr.last
        bh if diff_in_days <= 14 and diff_in_days > 0
      end.compact

      (arr + holidays)
    end

    def cool_dates(date, kind)
      cool_dates_array(date, kind).each_with_index.map do |d, i|
        if kind == 'mobile'
          mobile_cool_dates(d, i)

        elsif kind == 'iphone_app'
          str = Russian::strftime(d, '%A, %e %B')
          dates_hash(d, str)

        else
          str = case i
          when 0
            Russian::strftime(d, 'Сегодня, %e %B')
          when 1
            Russian::strftime(d, 'Завтра, %e %B')
          else
            Russian::strftime(d, '%A, %e %B')
          end

          dates_hash(d, str)

        end

      end
    end

    def mobile_cool_dates(date, index)
      str = case index
      when 0
        Russian::strftime(date, 'Сегодня %e %b')
      when 1
        Russian::strftime(date, 'Завтра %e %b')
      else
        Russian::strftime(date, '%a. %e %b')
      end

      verbose = Russian::strftime(date, '%e %B %Y')
      wday = Russian::strftime(date, '%A')

      dates_hash(date, str, { :verbose => verbose, :wday => wday })
    end

    def dates_hash(date, str, hash = {})
      { :date => date, :str => str }.merge(hash)
    end

  end


  def make_datetime(date, time)
    current_time_zone.local(date.year, date.month, date.day, time.hour, time.min)
  rescue TZInfo::AmbiguousTime => e
    current_time_zone.local(date.year, date.month, date.day, time.hour + 1, time.min)
  end

  def fix_zone!
    time_diff = (Time.zone.now.in_time_zone(place.city.time_zone).utc_offset - Time.zone.now.in_time_zone('Europe/Moscow').utc_offset) / 3600
    ALL_TIME_ATTRS.flatten.each do |day_times|
      self[day_times] = self[day_times] - time_diff.hours
    end
    save
  end

  def current_time_zone
    Time.zone = place.city.time_zone || 'Europe/Moscow'
    Time.zone
  end

  def current_default_in_time_zone
    [
      TIME_DEFAULTS.first.in_time_zone(place.city.time_zone),
      TIME_DEFAULTS.last.in_time_zone(place.city.time_zone)
    ]
  end

private

  def time_from(date)
    self[TIME_ATTRS[date.wday].first].in_time_zone
  end

  def time_to(date)
    self[TIME_ATTRS[date.wday].last].in_time_zone
  end

  # i need to be UTC wday
  def wday_time_from(i)
    self[TIME_ATTRS[i].first].in_time_zone.strftime('%H:%M')
  end
  def wday_time_to(i)
    self[TIME_ATTRS[i].last].in_time_zone.strftime('%H:%M')
  end

  def need_extraday?(date, time_splitted)
    if time_to(date) <= time_from(date)
      if time_splitted.first < time_to(date).hour or (time_splitted.first == time_to(date).hour and time_splitted.last <= time_to(date).min)
        return true
      end
    end

    return false
  end

  def time_correspond_to_timenet
    TIME_ATTRS.flatten.each do |t|
      errors.add(t, "Время не соответствует нашей сетке в #{Booking::TIMENET} минут")  if self[t].nil? or (self[t].in_time_zone.min % Booking::TIMENET != 0)
    end
  end

  def times_is_not_equal
    TIME_ATTRS.each do |day_times|
      errors.add(day_times.first, "Время начала и конца времени резерва не должны совпадать")  if self[day_times.first] == self[day_times.last]
    end
  end

  def set_defaults
    TIME_ATTRS.each do |day_times|
      self[day_times.first] = TIME_DEFAULTS.first.in_time_zone(place.city.time_zone) if self[day_times.first].blank?
      self[day_times.last] = TIME_DEFAULTS.last.in_time_zone(place.city.time_zone) if self[day_times.last].blank?
    end
  end

  # hack - setting AS nil values
  def set_as_nils
    self.lunch_from = nil if lunch_from.try(:hour).to_i == 0
    self.lunch_to = nil if lunch_to.try(:hour).to_i == 0
    self.mon_deposit_timefrom = nil if mon_deposit_timefrom.try(:hour).to_i == 0
    self.tue_deposit_timefrom = nil if tue_deposit_timefrom.try(:hour).to_i == 0
    self.wed_deposit_timefrom = nil if wed_deposit_timefrom.try(:hour).to_i == 0
    self.thu_deposit_timefrom = nil if thu_deposit_timefrom.try(:hour).to_i == 0
    self.fri_deposit_timefrom = nil if fri_deposit_timefrom.try(:hour).to_i == 0
    self.sat_deposit_timefrom = nil if sat_deposit_timefrom.try(:hour).to_i == 0
    self.sun_deposit_timefrom = nil if sun_deposit_timefrom.try(:hour).to_i == 0

    if mon_last_client
      self.mon_close_at = nil
    elsif mon_open_at.try(:hour).to_i == 0 and mon_close_at.try(:hour).to_i == 0
      self.mon_open_at = nil
      self.mon_close_at = nil
    end

    if tue_last_client
      self.tue_close_at = nil
    elsif tue_open_at.try(:hour).to_i == 0 and tue_close_at.try(:hour).to_i == 0
      self.tue_open_at = nil
      self.tue_close_at = nil
    end

    if wed_last_client
      self.wed_close_at = nil
    elsif wed_open_at.try(:hour).to_i == 0 and wed_close_at.try(:hour).to_i == 0
      self.wed_open_at = nil
      self.wed_close_at = nil
    end

    if thu_last_client
      self.thu_close_at = nil
    elsif thu_open_at.try(:hour).to_i == 0 and thu_close_at.try(:hour).to_i == 0
      self.thu_open_at = nil
      self.thu_close_at = nil
    end

    if fri_last_client
      self.fri_close_at = nil
    elsif fri_open_at.try(:hour).to_i == 0 and fri_close_at.try(:hour).to_i == 0
      self.fri_open_at = nil
      self.fri_close_at = nil
    end

    if sat_last_client
      self.sat_close_at = nil
    elsif sat_open_at.try(:hour).to_i == 0 and sat_close_at.try(:hour).to_i == 0
      self.sat_open_at = nil
      self.sat_close_at = nil
    end

    if sun_last_client
      self.sun_close_at = nil
    elsif sun_open_at.try(:hour).to_i == 0 and sun_close_at.try(:hour).to_i == 0
      self.sun_open_at = nil
      self.sun_close_at = nil
    end

  end

  def lunch_is_correct
    # потом добавить что ланч внутри сетки для понедельника-пятницы
    if lunch_from >= lunch_to
      errors.add(:lunch_from, "Время начала ланча должно быть больше конца")
    end
  end

  def deposit_is_correct
    WORKING_DAYS.each do |w_day|
      if (self["#{w_day}_deposit_type"].present? || self["#{w_day}_deposit_sum"].present?) && self["#{w_day}_deposit_str"].present?
        errors.add("#{w_day}_deposit_str", "Надо задать либо текстом депозит, либо тип депозита и сумму")
      end
    end
  end

end
