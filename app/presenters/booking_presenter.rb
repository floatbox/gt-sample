module BookingPresenter
  include ActionView::Helpers::TextHelper

  def yandex_state
    if waiting?
      'NEW'
    elsif user_notified?
      'USER_NOTIFIED'
    elsif paid?
      if transferred?
        # fucking iPad
        'APPROVED'
      else
        'ACCEPTED'
      end
    elsif place_confirmed? or serving?
      'APPROVED'
    elsif completed?
      'COME'
    elsif cancelled?
      if cancel_reasons_by_user.include? cancel_reason
        'CANCELLED_BY_USER'
      else
        'CANCELLED_BY_ORGANIZATION'
      end
    elsif overdue?
      'DID_NOT_COME'
    else
      'REJECTED'
    end

  end

  def mobile_state
    if time < DateTime.new(2015,11,18) && !user_step
      'old'
    elsif change_details?
      'change_details'
    elsif set_cancelled?
      'cancelled'
    elsif completed? && user_step && review.present?
      'checked_reviewed'
    elsif completed? && user_step
      'checked'
    elsif user_step
      'checked'
    elsif completed? && booking_revise && booking_revise.guest_status.present?
      'unchecked_confirmed'
    elsif completed? && booking_revise && booking_revise.place_status == 'overdue'
      'unchecked'
    elsif place_confirmed? || serving?
      'confirmed'
    elsif paid? && transferred? # fucking iPad
      'confirmed'
    elsif completed? || time < Time.zone.now
      'completed'
    elsif waiting? || user_notified? || paid?
      'waiting'
    elsif overdue?
      'overdue'
    else
      'old'
    end
  end

  def mobile_state_title
    case mobile_state
      when 'waiting'   then 'Бронь подтверждается'
      when 'confirmed' then 'Бронь подтверждена'
      when 'cancelled' then 'Бронь отменяется'
      when 'change_details' then 'Бронь переносится'
      else ''
      end
  end

  def mobile_state_description
    case mobile_state
      when 'old'       then ''
      when 'cancelled' then ''
      when 'change_details'
        action_params_str
      when 'waiting'
        "+1 балл будет зачислен в течение 48 часов.\nНе забудьте напомнить хостес, что вы от Gettable"
      when 'confirmed'
        "+1 балл будет зачислен в течение 48 часов.\nДля вас заказан столик на имя " + name
      when 'completed'
        "Ждем подтверждения от ресторана.\nБонус будет начислен в течение 48 часов"
      when 'checked'
        "Бонус получен!"
      when 'checked_reviewed'
        "Бонус получен!\nВаш отзыв опубликован!"
      when 'unchecked'
        "Ресторан указал что вы не посетили заведение"
      when 'unchecked_confirmed'
        "Ресторан не может найти вас в списках посетивших гостей, наши операторы свяжутся с вами"
      when 'overdue'
        "Администрация не подтвердила ваше присутствие. К сожалению, мы не зачислим бонус"
    end
  end

  def iphone_state
    if waiting? or user_notified?
      'waiting'
    elsif paid?
      if transferred?
        # fucking iPad
        'confirmed'
      else
        'waiting'
      end
    elsif place_confirmed? or serving?
      'confirmed'
    elsif completed? or overdue?
      'completed'
    elsif cancelled?
      'cancelled'
    else
      'waiting'
    end
  end

  def iphone_state_title
    case iphone_state
      when 'waiting'   then 'Заявка на бронь принята'
      when 'cancelled' then 'Бронь отменена'
      when 'confirmed' then 'Бронь подтверждена'
      when 'completed' then 'Бронь выполнена'
    end
  end

  def iphone_state_description
    common_phrases = ['Ваша бронь была отменена', 'К сожалению, ваш заказ был отменен', 'Ваша заявка была отменена']
    client_sms_message = last_sms ? last_sms.message.split('.').map{ |s| s unless common_phrases.map{|cp| cp == s.strip}.include?(true) }.compact.join('.') : nil
    cancel_description = "Ваш заказ на бронирование столика в #{place.category_with_title('p')} на #{nice_time(false)} был отменен."
    case iphone_state
      when 'waiting' then client_sms_message || "Ожидайте СМС-подтверждения резерва от #{place.category_name('r')}"
      when 'cancelled' then (last_sms.try(:booking_state).to_s == 'cancelled' && client_sms_message) ? client_sms_message : cancel_description
      when 'confirmed' then "Резерв держится 15 минут, при опоздании свяжитесь с нами:"
      when 'completed' then ''
    end
  end

  def iphone_state_phone
    iphone_state == 'confirmed' ? phone_for_sms : nil
  end

  def client_sms_options
    h = Time.zone.now.hour
    date = Date.tomorrow if h >= 21
    date = Date.today if h <= 18 # также подходит для случая 3 утра,все равно день уже сегодняшний
    date = booking_date if date.nil?
    booking_period = place.timetable.booking_period_for_date(date)
    category_name = place.category_name_allcases

    [
      { :title => 'Связываемся с менеджером (max- 20 мин)',
        :sms => "В данный момент мы связываемся с менеджером #{place.category_with_title('r')}, в течение 15 минут мы получим ответ, ожидайте СМС-подтверждения брони от заведения." },
      { :title => 'Менеджера нет на месте (через 30 мин. будет)',
        :sms => "К сожалению, на данный момент менеджера, принимающего брони в #{place.category_with_title('p')}, нет на месте. Ваша заявка принята, в течение 30 мин. мы свяжемся с менеджером и оповестим вас в СМС-сообщении о подтверждении брони." },
      { :title => "Не можем дозвониться до ресторана",
        :sms => "К сожалению, на данный момент мы не можем связаться с #{place.category_with_title('t')} из-за неполадок на линии #{category_name['r']}, наш колл-центр попробует сделать это в течение часа. Дождитесь СМС-подтверждения брони от #{category_name['r']}." },
      { :title => 'Поздно (23:00 - 4:00): Заведение уже закрыто',
        :sms => "Заведение уже закрыто. #{place.title} начинает прием резервов завтра в #{booking_period.first.strftime('%H:%M')}. Ваша заявка на бронь принята, и как только #{category_name['i']} откроется, мы моментально свяжемся с менеджером и оповестим вас в СМС-сообщении. " },
      { :title => 'Рано (от 4:00): Заведение еще закрыто',
        :sms => "Заведение еще закрыто. #{place.title} начинает прием резервов в #{booking_period.first.strftime('%H:%M')}. Ваша заявка на бронь принята, и как только #{category_name['i']} откроется, мы моментально свяжемся с менеджером и оповестим вас в СМС-сообщении." },
      { :title => 'Закрыто сегодня(изменить день)',
        :sms => "Заведение сегодня закрыто. #{place.title} начинает свою работу завтра в #{booking_period.first.strftime('%H:%M')}. Ваша заявка на бронь принята, и как только #{category_name['i']} откроется, мы моментально свяжемся с менеджером и оповестим вас в СМС-сообщении." },
      { :title => "Брони уже не принимают, но заведение еще работает(изменить время)",
        :sms => "К сожалению, на сегодня прием броней в #{category_name['p']} завершен. #{place.title} начинает прием броней завтра в #{booking_period.first.strftime('%H:%M')}. Ваша заявка принята, и как только заведение откроется, мы моментально свяжемся с #{category_name['t']} и оповестим вас в СМС-сообщении." },
      { :title => 'Надо позвонить клиенту',
        :sms => 'В ближайшее время с вами свяжется менеджер для уточнения деталей заказа.' },
      { :title => 'Перенесли резерв по времени',
        :sms => "Ваш резерв в #{place.title} был перенесен. Вас ожидают #{nice_time(true)}." },
      { :title => 'Изменили параметры брони (кол-во чел, заведение)',
        :sms => "Параметры вашего резерва в #{place.title} были изменены. Для вас забронирован столик на #{nice_time(true)} на #{persons} #{Russian::pluralize(persons, 'человека', 'человек', 'человек')}." },
      { :title => 'Отменяем бронь',
        :sms => "Ваш заказ на бронирование столика в #{place.category_with_title('p')} на #{nice_time(false)} был отменен." },
      { :title => 'Другая',
        :sms => '' },
      { :title => '[EN] Связываемся с менеджером(max-20 минут)',
        :sms => "We are contacting the manager of #{Russian::transliterate(place.title)} restaurant right now. Waiting period is 15 min. You will get the confirmation from the restaurant via SMS." }
    ]
  end

  def sms_confirmations_list
    @map_url = place.mobile_map_url
    @category_name = place.category_name_allcases

    { 1 => { "title" => 'Стандартное подтверждение',
             "sms" => sms_confirmation },
      5 => { "title" => 'Депозит заранее (предоплата, предзаказ)',
            "sms" => sms_deposit_client_confirm },
      7 => { "title" => 'Депозит по факту за стол (изменить сумму)',
            "sms" => sms_deposit_by_table },
      8 => { "title" => 'Депозит по факту за чел (изменить сумму)',
             "sms" => sms_deposit_by_person },
      9 => { "title" => 'Ривер Палас',
             "sms" => sms_confirmation_river_palas },
      10 => { "title" => '[EN] Стандартное подтверждение',
              "sms" => sms_confirmation_en },
      11 => { "title" => '[EN] Депозит заранее',
              'sms' => sms_deposit_before_en },
      12 => { "title" => '[EN] Депозит по факту (изменить сумму)',
              'sms' => sms_deposit_fact_en } }
  end

  def friend_notification_message
    "Для нас забронирован столик на имя #{name}. Нас ждут #{nice_time(true)} в #{place.category_with_title('p')}. Адрес: #{place.mobile_map_url}"
  end

  def mobile_sharing_text
    "Для нас забронирован столик в #{place.category_with_title('p')} на #{nice_time(true)}. Адрес: #{place.address_without_city} #{place.mobile_map_url}"
  end

  def booking_persons(lang = 'ru')
    case lang
    when 'ru'
      "#{persons} #{Russian::pluralize(persons, 'человек', 'человека', 'человек')}"
    when 'en'
      pluralize(persons, 'person')
    end
  end

  def sms_confirmation
    text = "Для вас забронирован столик на #{booking_persons} в #{place.category_with_title('p')} на #{nice_time(true)}. "
    text += "Адрес: #{place.address_without_city} #{@map_url}. "
    text += "Резерв держится 15 минут, при опоздании свяжитесь с нами: #{phone_for_sms}"

    change_details? ? text : (confirmation_text || text)
  end

  def sms_confirmation_en
    text =  "We have booked you a table for #{booking_persons('en')} at the #{Russian::transliterate(place.title)} restaurant for #{I18n.l(time, :format => "%B %e, %H:%M", :locale => :en)}. "
    text += "Address: #{Russian::transliterate(place.address_without_city)} #{@map_url}. "
    text += "Booking will be held for 15 minutes after the agreed booking time. Should you plans change, please let us know by phone at: #{phone_for_sms}"

    change_details? ? text : (confirmation_text || text)
  end

  def sms_confirmation_river_palas
    text = "Для вас забронирован столик в #{place.category_with_title('p')} на #{nice_time(true)}. "
    text += "Обратите внимание, приехать на причал необходимо за 30 минут до отправления теплохода. "
    text += "Вход 700 руб. с человека. Адрес: #{place.address_without_city} #{@map_url}."
  end

  def sms_deposit_before_en
    text =  "We have booked you a table at the #{Russian::transliterate(place.title)} restaurant for #{I18n.l(time, :format => "%B %e, %H:%M", :locale => :en)}. "
    text += "Address: #{Russian::transliterate(place.address_without_city)} #{@map_url}. "
    text += "Please, cover the deposit at the restaurant in advance."
  end

  def sms_deposit_fact_en
    text =  "We have booked you a table for #{booking_persons('en')} at the #{Russian::transliterate(place.title)} restaurant for #{I18n.l(time, :format => "%B %e, %H:%M", :locale => :en)}. "
    text += "Address: #{Russian::transliterate(place.address_without_city)} #{@map_url}. "
    text += "Please, don’t forget to cover the 10 000 rub. deposit upon arriving."
  end

  def sms_confirmation_deposit
    text = "На #{Russian.strftime(booking_date, '%e %B')} в #{place.category_with_title('p')} действует депозитная система. "
    text += "Для уточнения деталей заказа, в ближайшее время с вами свяжется менеджер #{@category_name['r']}. Приятного отдыха!"

    text
  end

  def sms_deposit_client_confirm
    text = "Для вас предварительно забронирован столик в #{place.category_with_title('p')} на #{nice_time(true)}. "
    text += "Адрес: #{place.address_without_city} #{@map_url}. "
    text += "Вас ожидают сегодня в #{@category_name['p']} для внесения депозита."
  end

  def sms_deposit_by_table
    text = "Для вас забронирован столик на #{booking_persons} в #{place.category_with_title('p')} на #{nice_time(true)}. "
    text += "Адрес: #{place.address_without_city} #{@map_url}. "
    text += "Не забудьте внести депозит в размере 10 000 руб. по факту прихода. "
    text += "Резерв держится 15 минут, при опоздании свяжитесь с нами: #{phone_for_sms}"
  end

  def sms_deposit_by_person
    text = "Для вас забронирован столик на #{booking_persons} в #{place.category_with_title('p')} на #{nice_time(true)}. "
    text += "Адрес: #{place.address_without_city} #{@map_url}. "
    text += "Не забудьте внести депозит в размере 1500 руб. с человека по факту прихода. "
    text += "Резерв держится 15 минут, при опоздании свяжитесь с нами: #{phone_for_sms}"
  end

  # при изменении обязательно проверить YandexState
  def cancel_reasons
    h = Time.zone.now.hour
    date = Date.tomorrow if h >= 21
    date = Date.today if h <= 18 # также подходит для случая 3 утра,все равно день уже сегодняшний
    date = booking_date if date.nil?
    booking_period = place.timetable.booking_period_for_date(date)
    category_name = place.category_name_allcases

    { 1 => { "title" => "Все столики заняты",
             "sms" => "К сожалению, ваш заказ был отменен. #{Russian::strftime(booking_date,'%e %B')} в #{place.category_with_title('p')} все столики уже заняты. Попробуйте выбрать другую дату или другое заведение." },
      2 => { "title" => "Связались с гостем, заказ отменен",
             "sms" => "Ваш заказ на бронирование столика в #{place.category_with_title('p')} на #{nice_time(false)} был отменен." },
      3 => { "title" => "Ресторан закрыт на спецобслуживание",
             "sms" => "К сожалению, #{place.category_with_title('i')} #{Russian::strftime(booking_date,'%e %B')} закрыт на спецобслуживание. Ваша заявка была отменена. Попробуйте выбрать другую дату или другое заведение." },
      4 => { "title" => "Не дозвонились в ресторан",
             "sms" => "К сожалению, мы не смогли связаться с #{place.category_with_title('t')} по причине неполадок на линии связи с #{category_name['t']}. Ваша заявка была отменена." },
      7 => { "title" => "Столики на 5 и больше закончились",
             "sms" => "К сожалению, ваш заказ был отменен. #{Russian::strftime(booking_date,'%e %B')} в #{place.category_with_title('p')} все столики на компании от 5 и более человек уже заняты. Попробуйте выбрать другую дату или другое заведение." },
      8 => { "title" => "Столики на 2 закончились(изменить кол-во)",
             "sms" => "К сожалению, ваш заказ был отменен. #{Russian::strftime(booking_date,'%e %B')} в #{place.category_with_title('p')} все столики на компании в 2 человека уже заняты. Попробуйте выбрать другую дату или другое заведение." },
      9 => { "title" => "Не дозвонились до клиента",
             "sms" => "К сожалению, мы не смогли дозвониться до вас для уточнения деталей заказа. Ваша заявка была отменена." },
      10 => { "title" => "Не реальное имя (Тест, итп)",
              "sms" => "Ваша бронь была отменена. Необходимо указать настоящее имя для того, чтобы #{category_name['i']} мог связаться с вами." },
      11 => { "title" => "Другая",
              "sms" => "" }
    }
  end

  def default_cancel_reason
    cancel_reasons[2]
  end

  def another_cancel_reason
    cancel_reasons[11]
  end

  def cancel_from_partner_reasons
    { 2 => default_cancel_reason,
      11 => another_cancel_reason }
  end

  def cancel_reasons_by_organization
    %w( 1 3 4 7 8 11 )
  end

  def cancel_reasons_by_user
    %w( 2 9 10 )
  end

  def cancel_reasons_serialized
    (cancelled_from ? cancel_from_partner_reasons : cancel_reasons).map{ |k, v| v['id']=k; v }
  end

  def sms_processing_order
    "Ваш заказ принят. Ожидайте СМС-подтверждения брони от #{place.category_name('r')}."
  end

  def sms_notify
    if notify_me and notify_me <= 900 and Time.zone.now.to_date == booking_date
      "Gettable напоминает, вас ожидают сегодня в #{place.category_with_title('p')} через #{distance_of_time_in_hours_and_minutes(notify_me)}. Резерв держится 15 минут, при опоздании свяжитесь с нами:  #{phone_for_sms}"
    elsif notify_me
      "Gettable напоминает, вас ожидают в #{place.category_with_title('p')} #{Russian::strftime(time, "%e %B в %H:%M")}. Резерв держится 15 минут, при опоздании свяжитесь с нами:  #{phone_for_sms}"
    end
  end

  def distance_of_time_in_hours_and_minutes(minutes_count)
    distance_in_hours   = (minutes_count / 60).round
    distance_in_minutes = (minutes_count % 60).round

    difference_in_words = []

    difference_in_words << "#{distance_in_hours} #{Russian::pluralize(distance_in_hours, 'час', 'часа', 'часов')}" if distance_in_hours > 0
    difference_in_words << "#{distance_in_minutes} #{Russian::pluralize(distance_in_minutes, 'минуту', 'минуты', 'минут')}" if distance_in_minutes > 0
    difference_in_words.join(' ')
  end

  def sms_callcenter_girl
    "Новая бронь в #{place.title}"
  end

  def sms_cancel_notify
    "Отменить бронь в #{place.title} от #{source}"
  end

  def sms_autocancel_notify
    "Автоматическая отмена брони в #{place.title} от #{source}"
  end

  def push_message
    mes = "Бронь на #{I18n.l(booking_date, :format => '%e %B')}. Клиент #{name}."
    mes += " Зона: #{room_translated_title}" if room_translated_title and room_title != 'any'
    mes += " Комментарий: #{user_comment}" if user_comment.present? and user_comment != 'Пожелание к брони'

    mes
  end

  def nice_time(with_today = false, pretext = ' в ')
    if with_today and booking_date <= Date.today
      night = night_booking? ? " ночью" : ""
      str = "сегодня#{night}#{pretext}#{I18n.l(time, :format => "%H:%M")}"
    else
      str = Russian::strftime(time, "%e %B#{pretext}%H:%M")
      str += " (#{night_booking_description})" if night_booking?
    end

    str.strip
  end

  def night_booking_description
    if night_booking?
      preposition = ['с', 'со', 'со', 'с', 'с', 'с', 'с'][booking_date.wday - 1]
      day_from = ['понедельника', 'вторника', 'среды', 'четверга', 'пятницы', 'субботы', 'воскресенья'][booking_date.wday - 1]
      day_to = ['понедельник', 'вторник', 'среду', 'четверг', 'пятницу', 'субботу', 'воскресенье'][booking_date.wday]
      "ночь #{preposition} #{day_from} на #{day_to}"
    end
  end

  def description
    "Бронь столика на #{nice_time} в «#{place.title}»"
  end

  def mail_subject
    "Заказ столика в #{place.title} на #{Russian::strftime(time, "%e %B")}"
  end

  def room_translated_title
    case room_title
      when 'any' then 'Не важно'
      when 'smoking' then 'Курящая'
      when 'nosmoking' then 'Не курящая'
      else nil
    end
  end

  def stringify_persons
    "#{persons} #{Russian::pluralize(persons, 'человек', 'человека', 'человек')}"
  end

  def filtered_phone
    length = phone.length
    phone[0...length - 4] + ('*' * 4) if length > 4
  end

  def kind_for_tables_list
    if temporary?
      'временная'
    elsif common?
      'депозит'
    else
      'оффлайн'
    end
  end

  def stringified_date(current_booking_date)
    if current_booking_date == booking_date
      ''
    elsif current_booking_date.yesterday == booking_date
      'вчера'
    elsif current_booking_date.tomorrow == booking_date
      'завтра'
    else
      I18n.l(time, :format => :reservation_time_ipad)
    end
  end

  def color_booking_list
    if overdue?
      'red'
    elsif serving? or completed?
      'completed'
    elsif false
      # it was old logic for preorder
      'green'
    elsif paid? and (Time.zone.now - time).to_i/60 > 15
      'overdue'
    else
      'gray'
    end
  end

  def ordered_room
    if res = room_translated_title
      res += "<br /><span style='background-color:rgb(255, 239, 0);'>Клиент согласен изменить зону</span>" if room_title != 'any' and allow_transfer
      res
    else
      order_room.try(:title) || room.try(:title)
    end
  end

  def state_color
    case state
    when 'overdue'
      '#CC0033'
    when 'paid'
      '#99FF99'
    when 'serving'
      '#00CC00'
    when 'completed'
      '#00CC33'
    when 'cancelled'
      '#FF6666'
    when 'waiting'
      '#CCFF99'
    when 'place_confirmed'
      '#99FF66'
    when 'expired'
      '#FF9999'
    end
  end

  def track_times
    track_times = [ ]

    track_times << if operator_set_at
      t = (operator_set_at - created_at) / 60.minutes
      "#{t.round} мин."
    else
      " - "
    end

    track_times << if smses_count > 0
      t = (smses.first(:order => 'created_at asc').created_at - created_at) / 60.minutes
      "#{t.round} мин."
    else
      " - "
    end

    track_times << if transferred_at
      t = (transferred_at - created_at) / 60.minutes
      "#{t.round} мин."
    else
      " - "
    end

    track_times
  end

  def persons_count_category
    case persons
    when 2
      '2'
    when 3..5
      '3to5'
    when 6..30
      '6plus'
    end
  end

  def secret_type
    return nil if Rails.env.test?

    case
    when Partner.our_site_sources.include?(source) && utm_source
      case
      when utm_source =~ /yandex_ppc/
        'Yandex'
      when utm_source =~ /mobile_google_ppc/
        'Google Mob'
      when utm_source =~ /pctab_google_ppc/ || %w(google_ppc spb_google_ppc).include?(utm_source)
        'Google PC'
      when !%w(yandex mailing phone).include?(utm_source) && !utm_source.include?('_ppc')
        'Organic'
      end

    when source == 'gettable-iphone'
      'GT iPhone'
    when Partner.mobile_without_site.include?(source)
      'Mob other'
    when source == 'afisha'
      'Afisha Site'
    when Partner.sindikat_sources.include?(source)
      'Sindikat'
    when Partner.novikoff_sources.include?(source)
      'Novikov'
    when source == 'yandex-islands'
      'Islands'
    when source == 'gettable-phone'
      'Call Center'
    when source == 'prime_resto'
      'PrimeR'
    when Partner.resto_partners.include?(source)
      'Resto sites'
    when Partner.portal_partners.include?(source)
      'Portals'
    when Partner.phone_portal_sources.include?(source)
      'Phone Portals'
    when Partner.fb_partners.include?(source)
      'FB'
    else
      'Other'
    end
  end

  def action_params_str
    if action_params
      action_params.inject("") do |memo, (type, value)|
        case type
        when 'time'
          memo += "Изменить время на #{Russian::strftime(value.to_time, "%d %B")} в #{Russian::strftime(value.to_time, "%H:%M")}. "
        when 'persons'
         memo += "Изменить гостей на #{value}. "
        end

        memo
      end
    end
  end

  def action_params_comment
    action_params[:comment] if action_params && !action_params[:comment].blank?
  end


  def time_details_date
    time.strftime('%Y-%m-%d')
  end

  def time_details_time
    time.strftime('%H:%M')
  end

  def full_booking_time
    time.strftime('%d.%m.%Y %H:%M')
  end

  ## All time attrs should be in place time_zone

  def time
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def payed_at
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def serve_from
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def serve_to
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def cancelled_at
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def transferred_at
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def operator_set_at
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def overdue_at
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

  def original_time
    super.in_time_zone(place.city.time_zone) if super && place.try(:city).try(:time_zone)
  end

end
