module TimetablePresenter
  RUS_WORKING_DAYS = %w(mon tue wed thu fri sat sun)

  def state_for_time(date, time, phone)
    # раньше смотрелось availabilities.time(time).count - для каждого тайм слота,
    # но по факту пока не используется, поэтому пока через .date(..)
    {
      :time => time.strftime("%H:%M"),
      :full_time => time,
      :state => availabilities.date(date).count > 0 ? 'corporate' : 'active',
      :special_info_type  => special_info_type(date),
      :special_info_title => special_info_title(date, time, phone),
      :special_info_title_short => special_info_title_short(date, time, phone),
      :special_info_from  => special_info_from(date)
    }
  end

  def timenet_message(date)
    if day_off?(date) and day_off_kind == 'day_off'
      { :full => "К сожалению, «#{place.title}» не работает #{weekday_message(date)}.",
        :short => "Не работает" }
    elsif day_off?(date) and day_off_kind == 'no_reserve'
      { :full => "К сожалению, «#{place.title}» не принимает резервы #{weekday_message(date)}.",
        :short => "Не принимают резервы" }
    elsif ny_offline_day?
      { :full => "Gettable поздравляет вас с Новым годом! Мы продолжим бронировать для вас столики 1 января.",
        :short => "С Новым годом!" }
    elsif place.id == 1049 && !available_on?(date) ## Жеральдин!
      { :full => "К сожалению, #{Russian::strftime(date, '%e %B')} «#{place.title}» не принимает резервы онлайн. Звоните в ресторан.",
        :short => "Не принимает резервы" }
    elsif !available_on?(date) and (Date.new(2014,1,1)..Date.new(2014,1,8)).include?(date)
      { :full => "К сожалению, «#{place.title}» не работает #{Russian::strftime(date, '%e %B')}.",
        :short => "Не работает" }
    elsif !available_on?(date)
      { :full => "К сожалению, #{Russian::strftime(date, '%e %B')} в «#{place.title}» нет свободных мест.",
        :short => "Нет свободных мест" }
    elsif !place.active? && place.fake
      { :full => "К сожалению, «#{place.title}» временно не принимает резервы онлайн. Звоните: #{place.formatted_phones.first}",
        :short => "Не принимает резервы" }
    elsif !place.active?
      { :full => "К сожалению, «#{place.title}» временно не принимает резервы.",
        :short => "Не принимает резервы" }
    else
      { :full => "",
        :short => "" }
    end
  end

  def working_time(break_str = ',<br />')
    hs = {}
    [1,2,3,4,5,6,0].each_with_index do |d, i|
      wtime = weekday_working_time(d)
      if wtime
        if hs[wtime]
          hs[wtime] << i
        else
          hs[wtime] = [i]
        end
      end
    end

    res = hs.values.sort{|x,y| x.first <=> y.first }.map do |it|
      grouped_days = []
      internal_i = 0
      it.sort.each_with_index do |dnum, i|
        if internal_i == i
          dname = Unicode::downcase( "#{Russian::strftime(Date.today.beginning_of_week + dnum, '%a')}." )
          if i == 0
            grouped_days = [ dname ]
          else
            if dnum == it[i - 1] + 1 and dnum + 1 == it[i + 1]
              it[i + 1..-1].each_with_index do |new_dnum, i|
                if new_dnum != dnum + 1
                  break
                else
                  dnum += 1
                  internal_i += 1
                end
              end
              last_group = grouped_days.last.split(' – ')
              dname = Unicode::downcase( "#{Russian::strftime(Date.today.beginning_of_week + dnum, '%a')}." )
              grouped_days[-1] = "#{last_group.first} – #{dname}"
            else
              grouped_days << dname
            end
          end
          internal_i += 1
        end
      end

      "#{grouped_days * (', ')} #{hs.invert[it]}"
    end.join(break_str)

    Unicode::capitalize( res )
  end

  def weekday_message(date)
    case date.wday
    when 0
      'по воскресеньям'
    when 1
      'по понедельникам'
    when 2
      'по вторникам'
    when 3
      'по средам'
    when 4
      'по четвергам'
    when 5
      'по пятницам'
    when 6
      'по субботам'
    end
  end

  def special_info_title(date, time, phone)
    if special_info_type(date).to_s == 'terms' and !phone
      special_title || "Действуют особые условия"
    elsif premoney?(date)
      premoney_str(date, time, phone)
    end
  end

  def special_info_title_short(date, time, phone)
    case special_info_type(date).to_s
    when 'terms'
      'Особые условия'
    when 'deposit'
      deposit_sum(date) ? "Депозит от #{deposit_sum(date).to_i} руб." : 'Депозит'
    end
  end

  def special_info_where
    booking_terms.map{ |term| term.where }.join(', ')
  end

  def special_info_tags
    booking_terms.present? ? booking_terms.map{ |term| term.additional_titles }.join(', ') : nil
  end

  def premoney_str(date, time, phone)
    deposit_day?(date) ? deposit_str(date, time, phone) : entrance_str(date)
  end

  def entrance_str(date)
    common_str = "Стоимость входа"
    sum_str = "#{entrance_sum(date).to_i}&nbsp;руб."
    case date.wday
    when 0
      "#{common_str} в воскресенье: #{sum_str}"
    when 1
      "#{common_str} в понедельник: #{sum_str}"
    when 2
      "#{common_str} во вторник: #{sum_str}"
    when 3
      "#{common_str} в среду: #{sum_str}"
    when 4
      "#{common_str} в четверг: #{sum_str}"
    when 5
      "#{common_str} в пятницу: #{sum_str}"
    when 6
      "#{common_str} в субботу: #{sum_str}"
    end
  end

  def deposit_str(date, time, phone)
    num_sum = " от&nbsp;#{deposit_from(date)}&nbsp;чел." if deposit_from(date).to_i > 2
    dtime = deposit_timefrom(date)
    if dtime.present?
      if (phone or time >= dtime) and dtime != booking_period_for_date(date).first
        time_str = " с&nbsp;#{dtime.strftime('%H:%M')}"
      end
    end
    common_str = "действует депозит#{time_str ||= ''}#{num_sum}:"

    deposit_sum_str = if deposit_type(date) and deposit_sum(date) and (phone or dtime.nil? or (dtime.present? and time >= dtime))
      case deposit_type(date)
      when 'person'
        "#{deposit_sum(date).to_i}&nbsp;руб.&nbsp;с&nbsp;чел."
      when 'table'
        "#{deposit_sum(date).to_i}&nbsp;руб.&nbsp;за&nbsp;стол"
      end
    elsif deposit_description(date) and (phone or dtime.nil? or (dtime.present? and time >= dtime))
      deposit_description(date)
    end

    if phone or dtime.blank? or (dtime.present? and time >= dtime)
      case date.wday
      when 0
        "В воскресенье #{common_str} #{deposit_sum_str ||= ''}"
      when 1
        "В понедельник #{common_str} #{deposit_sum_str ||= ''}"
      when 2
        "Во вторник #{common_str} #{deposit_sum_str ||= ''}"
      when 3
        "В среду #{common_str} #{deposit_sum_str ||= ''}"
      when 4
        "В четверг #{common_str} #{deposit_sum_str ||= ''}"
      when 5
        "В пятницу #{common_str} #{deposit_sum_str ||= ''}"
      when 6
        "В субботу #{common_str} #{deposit_sum_str ||= ''}"
      end
    end
  end

  def deposit_summary(delimeter = "\n<br>")
    (0..6).map do |d|
      date = d.days.since
      deposit_str(date, deposit_timefrom(date), false) if deposit_day?(date)
    end.compact.join(delimeter) if deposit?
  end

  def lunch_summary
    if lunch_type
      return 'нет' if lunch_type == 'no'

      parts = []
      parts << (lunch_booking.present? ? 'Бронят.' : 'Не бронят.')

      parts << case lunch_type
      when 'discount' then 'Скидка'
      when 'special_menu' then 'Меню'
      end

      parts << "с #{lunch_from.strftime('%H:%M')}" if lunch_from
      parts << "до #{lunch_to.strftime('%H:%M')}" if lunch_to
      parts = ["#{parts.join(' ')}."] if parts.any?

      parts << lunch_description if lunch_description
      parts << lunch_prices if lunch_prices

      parts.join(' ')
    end
  end

  ## Special for Yandex API

  def working_days_mask
    RUS_WORKING_DAYS.each_with_index.map{ |it, i| i + 1 if self[it] }.compact
  end

  def grouped_working_mask
    working_days_mask.each_with_object({}) do |i, h|
      tr = time_range_on_wday(wday_to_eu(i - 1))
      if h.values.include? tr
        k = h.invert[tr]
        wdays_arr = [ k.last.to_i, i]
        if lunch_booking? or
            ( ((1..5).to_a & wdays_arr) == wdays_arr) or
            ( ((6..7).to_a & wdays_arr) == wdays_arr)
          i = "#{k}#{i}"
          h.delete(k)
        end
      end

      h[i.to_s] = tr
    end
  end

  def time_frames(wday)
    result = []
    date = Timetable.next_week + wday.to_i.days

    unless day_off?(date)
      current_time = booking_period_for_date(date).first
      # 15.minutes for Yandex - they are a little bit stupid
      booking_to = booking_period_for_date(date).last + 15.minutes

      while current_time <= booking_to
        if can_book_on_time?(date, current_time)
          result << current_time
        end

        # this is for Yandex too
        current_time += if current_time + 15.minutes == booking_to
          15.minutes
        else
          Booking::TIMENET.minutes
        end
      end
    end

    result.each_with_index.map do |t, i|
      unless t == result.last
        if ((result[i + 1] - t) == Booking::TIMENET.minutes or (result[i + 1] - t) == 15.minutes)
          { :from => t.strftime('%H:%M'), :to => result[i + 1].strftime('%H:%M') }
        end
      end
    end.compact
  end

  def time_range_on_wday(i)
    "#{wday_time_from(i)} - #{wday_time_to(i)}"
  end

  def slots_array(date_from = nil, date_to = nil, res_ids = [], smoke = nil, persons = nil, show_banned = false)
    result = []
    date_from = booking_date_for_time(Time.zone.now) if date_from.blank?
    date_to = date_from + 2.weeks if date_to.blank?

    (date_from..date_to).each_with_index do |date, i|
      current_time = booking_period_for_date(date).first
      booking_to = booking_period_for_date(date).last + 15.minutes
      day_close = date_closed?(date)

      if res_ids.blank?
        res_ids = place.landing_resources.map do |lr|
          if smoke.present? and persons.nil?
            lr[:res_id] if lr[:hallType] == smoke
          elsif persons.present? and smoke.nil?
            lr[:res_id] if lr[:guestsCount].to_s == persons
          elsif persons.present? and smoke.present?
            lr[:res_id] if (lr[:hallType] == smoke) and (lr[:guestsCount].to_s == persons)
          else
            lr[:res_id]
          end
        end.compact
      end

      res_ids.each do |res_id|
        while current_time < booking_to
          # remove old condition - current_time < 15.minutes.from_now -
          #                        because YandexInterface working with that correctly

          # this is for Yandex too
          timenet_step = if current_time + 15.minutes == booking_to
            15.minutes
          else
            Booking::TIMENET.minutes
          end
          banned = (day_close || !can_book_on_time?(date, current_time) )
          attrs = { "from" => I18n.l(current_time, :format => :yandex),
                    "to" => I18n.l(current_time + timenet_step, :format => :yandex) }
          attrs.merge!({"hallType" => smoke}) if smoke.present?
          attrs.merge!({"guestsCount" => persons}) if persons.present?

          if show_banned == banned
            result << { :resourceId => res_id, :slotId => "#{res_id}##{I18n.l(current_time, :format => :yandex)}",
                        :attributes => attrs, :organizationId => place_id }
          end

          # this is for Yandex too
          current_time += timenet_step
        end
      end

    end

    result
  end

end
