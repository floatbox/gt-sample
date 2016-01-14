# encoding: UTF-8
module PlacePresenter
  include Site::LandingsHelper

  TYPE_CONVERSION = { :features => { 'friends' => 'friends_purpose', 'romantic' => 'dating_purpose',
                                     'business' => 'business_purpose', 'family' => 'family_purpose',
                                     'center' => 'center', 'credit_cards' => 'credit_cards',
                                     'until_morning' => 'until_morning', 'cool_view' => 'cool_view',
                                     'shisha' => 'shisha', 'comfortable_sofas' => 'comfortable_sofas',
                                     'child_menu' => 'child_menu', 'sport_translation' => 'sport_translation',
                                     'vinoteka' => 'vinoteka', 'wifi' => 'wifi', 'dontsmoke_zone' => 'dontsmoke_zone',
                                     'karaoke' => 'karaoke', 'lounge_atm' => 'lounge_atm', 'terrace' => 'terrace',
                                     'terrace_on_roof' => 'terrace_on_roof', 'around_the_clock' => 'around_the_clock' },
                      :cuisines => { 'italian_cuisine' => 'italian_cuisine', 'russian_cuisine' => 'russian_cuisine',
                                     'japan_cuisine' => 'japan_cuisine', 'maestro_cuisine' => 'maestro_cuisine',
                                     'european_cuisine' => 'european_cuisine', 'american_cuisine' => 'american_cuisine',
                                     'georgia_cuisine' => 'georgia_cuisine', 'chinese_cuisine' => 'chinese_cuisine',
                                     'panaziat_cuisine' => 'panaziat_cuisine', 'fish_cuisine' => 'fish_cuisine',
                                     'french_cuisine' => 'french_cuisine', 'uzbek_cuisine' => 'uzbek_cuisine',
                                     'beerrest_cuisine' => 'beerrest_cuisine', 'mexican_cuisine' => 'mexican_cuisine',
                                     'thai_cuisine' => 'thai_cuisine', 'vietname_cuisine' => 'vietname_cuisine',
                                     'arab_cuisine' => 'arab_cuisine' }
                    }

  ORDER_CONVERSION = { 1 => 'avg_price asc, title asc',
                       2 => 'avg_price desc, title asc',
                       3 => 'votes desc, title asc',
                       4 => 'random()' }

  BREAK_KINDS = { 'closed_forever' => 'ресторан закрылся навсегда',
                  'contract_terminated' => 'расторгли договор',
                  'change_location' => 'переезжают на другое место',
                  'repair' => 'ремонт',
                  'financial_problems' => 'не платят / финансовые проблемы',
                  '3month_debt' => 'не платят 3 месяца',
                  'conflict' => 'конфликт с нами / не принимают брони',
                  'reconclude_contract' => 'переподписываем договор(смена юр лица / новые условия)',
                  'internal_problems' => 'внутренние проблемы у ресторана',
                  'no_contract' => 'нет договора',
                  'other' => 'другая' }

  LOGO_STYLES =  { :main_ad => ['180x65>', 'jpg'],
                   :barpage => ['210x100>', 'jpg'],
                   :retarget_250x250 => ['x83', 'jpg'],
                   :retarget_200x200 => ['x65', 'jpg'],
                   :retarget_336x280 => ['x105', 'jpg'],
                   :retarget_300x250 => ['x100', 'jpg'],
                   :retarget_300x600 => ['x118', 'jpg'] }

  FULL_CATEGORIES = { 'restaurant' => { 'i' => 'ресторан',
                                        'r' => 'ресторана',
                                        'd' => 'ресторану',
                                        'v' => 'ресторан',
                                        't' => 'рестораном',
                                        'p' => 'ресторане',
                                        'plural' => 'рестораны',
                                        'plural_p' => 'ресторанах' },
                      'cafe' =>       { 'i' => 'кафе',
                                        'r' => 'кафе',
                                        'd' => 'кафе',
                                        'v' => 'кафе',
                                        't' => 'кафе',
                                        'p' => 'кафе',
                                        'plural' => 'кафе',
                                        'plural_p' => 'кафе' },
                      'bar' =>        { 'i' => 'бар',
                                        'r' => 'бара',
                                        'd' => 'бару',
                                        'v' => 'бар',
                                        't' => 'баром',
                                        'p' => 'баре',
                                        'plural' => 'бары',
                                        'plural_p' => 'барах' },
                      'club' =>       { 'i' => 'клуб',
                                        'r' => 'клуба',
                                        'd' => 'клубу',
                                        'v' => 'клуб',
                                        't' => 'клубом',
                                        'p' => 'клубе',
                                        'plural' => 'клубы',
                                        'plural_p' => 'клубах' } }


  RETARGETING_STYLES = [ :retarget_250x250, :retarget_200x200, :retarget_336x280, :retarget_300x250, :retarget_300x600 ]

  # elasticsearch не может проиндексировать place с location [nil, nil]
  def coordinates
    [ latitude, longitude ].compact
  end

  def coordinates?
    longitude && latitude
  end

  def location
    [ longitude, latitude ].compact
  end

  def postal_coordinates
    (postal_address_lat && postal_address_lon) ? [postal_address_lat, postal_address_lon] : coordinates
  end

  def title_with_city
    title + " (#{city.name})"
  end

  def address_without_city
    address.to_s.split(', ').delete_if{|it| %w(Москва Санкт-Петербург Казань Екатеринбург).include?(it)}.join(', ')
  end

  def postal_address_without_city
    postal_address.present? ? postal_address.to_s.split(', ').delete_if{|it| it == 'Москва'}.join(', ') : address_without_city
  end

  def yandex_address
    excluded_patterns = ["торговый центр ", "гостиница ", "ТЦ ", ' этаж']
    adrs = address_without_city.gsub(/&laquo;|&raquo;/,'').gsub(/&nbsp;|&nbsp/,' ').strip.split(',')
    adrs.split(',').map do |address_part|
      unless excluded_patterns.map{ |ep| address_part.include?(ep) }.include? true
        address_part
      end
    end.compact.join(',')
  end

  def yandex_rubrics
    rubrics = []
    # rubrics << 35193114937 if specializations.where(yandex_value: 'coffee_house').count > 0
    # rubrics << 770931537 if specializations.where(yandex_type: 'sports_broadcasts').count > 0
    rubrics += { restaurant: 184106394, cafe: 184106390, bar: 184106384, club: 184106384 }.map{ |k,v| v if self[k] }
    rubrics.compact.uniq[0..2]
  end

  def yandex_type_cuisine
    features.where(yandex_type: 'type_cuisine').pluck(:yandex_value).compact.uniq
  end

  def yandex_type_special_menu
    features.where(yandex_type: 'special_menu').pluck(:yandex_value).compact.uniq
  end

  def nice_site_url
    if site_url.present?
      site_url.include?('http') ? site_url : "http://#{site_url.strip}"
    end
  end

  def mobile_deeplink
    'gettable://places/' + id.to_s
  end

  def mobile_booking_deeplink
    'gettable://places/' + id.to_s + '/booking'
  end

  def yandex_type_public_catering
    catering_types = []
    catering_types << 'fish_restaurant' if specializations.where(yandex_value: 'fish_cuisine').count > 0
    catering_types << 'steak_house' if specializations.where(yandex_value: 'meat_cuisine').count > 0
    catering_types << 'restaurant' if preferred_category == 'restaurant'
    catering_types << 'cafe_type' if preferred_category == 'cafe'
    catering_types << 'bar' if preferred_category == 'bar'
    catering_types + features.where(yandex_type: 'type_public_catering').pluck(:yandex_value).compact.uniq
  end

  def yandex_features
    features.where('yandex_type is not null and yandex_type != ? and yandex_type not in (?)', '', %w( type_public_catering type_cuisine special_menu )).pluck(:yandex_type).compact.uniq
  end

  def yandex_known_features
    Feature.where('yandex_type is not null and yandex_type != ? and yandex_type not in (?)', '', %w( type_public_catering type_cuisine special_menu )).pluck(:yandex_type).compact.uniq
  end

  def category_name(case_name = 'i', capitalized = false)
    catname = FULL_CATEGORIES[preferred_category][case_name]
    capitalized ? Unicode::capitalize(catname) : catname
  end

  def category_name_allcases
    FULL_CATEGORIES[preferred_category]
  end

  def category_with_title(case_name = 'i', capitalized = false)
    title_categorized ? title.strip : "#{category_name(case_name, capitalized)} #{title.strip}"
  end

  def category_with_title_quotes(case_name = 'i', capitalized = false)
    title_categorized ? "«#{title.strip}»" : "#{category_name(case_name, capitalized)} «#{title.strip}»"
  end

  def short_title
    (place_group && place_group.common_title) ? place_group.title : title
  end

  def menu_title
    if (menu_items_count = menu_items.active.count) > 0
      "#{menu_items_count} #{Russian::pluralize(menu_items_count, 'Блюдо', 'Блюда', 'Блюд')} меню"
    end
  end

  def mobile_sharing_text
    "#{category_with_title('i', true)}"
  end

  def contract_num
    contract.try(:number)
  end

  def contract_date
    contract.try(:date)
  end

  def contract_responsible
    agent.try(:ceo_short_name)
  end

  def documents_sign_responsible
    documents_sign_by.present? ? documents_sign_by : contract_responsible
  end

  def agent_1c_uid
    agent.try(:agent_1c_uid)
  end

  def contract_1c_uid
    contract.try(:contract_1c_uid)
  end

  def agent_full_name
    if agent
      [Agent::KIND[agent.kind], agent.name].join(' ')
    end
  end

  def contract_llc
    agent_full_name
  end

  def vector_param
    "place_#{id}_vector"
  end

  def similar_param
    "place_#{id}_similarto"
  end

  def all_phones
    phone.to_s.split(/,|;/).flatten.map{ |p| p.strip }.uniq
  end

  def first_phone
    all_phones.first.to_s.gsub(/[(,)]/,'')
  end

  def banquet_phones
    banquet_employees = employees.working.with_phone.banquet.all.map{ |e| "#{e.name}, тел. #{e.phone}" }
    banquet_employees.present? ? banquet_employees.join('<br />') : "По тел. рест."
  end

  def birthday_offer
    if birthday_discount && birthday_discount > 0
      prefix = birthday_description.blank? ? "Скидка #{birthday_discount}% для именинников." : birthday_description

      suffix = case
      when birthday_days_before > 0 && birthday_days_after > 0
        "Действует за #{days_with_pluralize(birthday_days_before)} до и #{days_with_pluralize(birthday_days_after)} после дня рождения."
      when birthday_days_after > 0
        "Действует #{days_with_pluralize(birthday_days_after)} после дня рождения."
      when birthday_days_before > 0
        "Действует #{days_with_pluralize(birthday_days_before)} до дня рождения."
      else
        "Действует только в день рождения."
      end

      prefix + ' ' + suffix
    else
      birthday_description
    end
  end

  def common_booking(user)
    if user.next_gift_steps
      steps_to_gift = user.next_gift_steps - user.steps_sum
      { state: active? ? 'active' : 'hidden',
        title: 'Заказать столик',
        description: steps_to_gift > 0 ? "Еще #{steps_to_gift} #{pluralize_booking(steps_to_gift)} столика до подарка" : '' }
    else
      { state: active? ? 'active' : 'hidden',
        title: 'Заказать столик',
        description: "Мы дарим +1 бонус за заказ столика" }
    end
  end

  def fast_booking(user)
    ## turn off fast booking for the first release
    state = if active? && false
      nearest_booking_time = timetable.nearest_booking_time(get_booking_date)
      if nearest_booking_time && (nearest_booking_time - Time.zone.now <= 30.minutes)
        'active'
      else
        state_description = 'К сожалению, нельзя забронировать столик на ближайшее время'
        'disabled'
      end
    else
      'hidden'
    end
    { state: state,
      title: 'БУДУ ЧЕРЕЗ 15 МИНУТ',
      persons: (min_persons..max_persons).to_a[0..9],
      booking_time: state == 'active' ? nearest_booking_time.strftime('%H:%M') : nil,
      booking_date: state == 'active' ? get_booking_date : nil,
      description: state_description ||= nil }
  end

  def days_with_pluralize(count)
    "#{count} #{pluralize_days(count)}"
  end

  def pluralize_days(count)
    Russian::pluralize(count, 'день', 'дня', 'дней')
  end

  def pluralize_booking(count)
    Russian::pluralize(count, 'заказ', 'заказа', 'заказов')
  end

  def menu_global_categories_array
    menu_global_categories.map do |mgc|
      mgc if menu_categories.with_active_menu_items.where(menu_global_category_id: mgc.id).count > 0
    end.compact
  end

  def landing_resources
    zones_array(true).each_with_object([]) do |z, arr|
      (min_persons..10).map do |p|
        arr << { :guestsCount => p, :hallType => yandex_smoke(z), :res_id => "#{id}-#{z}-#{p}",
                 :description => "Столик на #{p} человек, #{zone_name(z)}" }
      end
    end
  end

  def yandex_smoke(zone)
    (zone == 'nosmoking') ? 'nonsmoking' : zone
  end

  def our_smoke(zone)
    (zone == 'nonsmoking') ? 'nosmoking' : zone
  end

  def zones_array(with_any = false)
    zones == 'any' ? Place::ALL_ZONES.keys.sort : ( with_any ? [ 'any', zones ] : [ zones ] )
  end

  def zone_name(zone)
    Place::ALL_ZONES[zone]
  end

  def persons_select
    (min_persons..max_persons).map{ |p| { :value => p, :str => "#{p} #{Russian::pluralize(p, 'человек', 'человека', 'человек')}" } }
  end

  def main_photo
    place_photos.main_landing.sorted.first
  end

  def search_image
    main_photo.try(:new_search)
  end

  def main_search_image
    main_photo.try(:main_search)
  end

  def search_map_image
    main_photo.try(:search_map)
  end

  def iphone_booking_image
    main_photo.try(:iphone_booking)
  end

  def iphone_booking_image_2x
    main_photo.try(:iphone_booking_2x)
  end

  def iphone_booking_image_3x
    main_photo.try(:iphone_booking_3x)
  end

  def mobile_list_2x
    main_photo.try(:mobile_list_2x)
  end

  def mobile_list_3x
    main_photo.try(:mobile_list_3x)
  end

  def main_similar_image
    main_photo.try(:similar)
  end

  def main_banquet_image
    main_photo.try(:similar)
  end

  def landing_link
    "https://#{city.permalink + '.' unless city_id == 1}gettable.ru#{link}"
  end

  def mobile_sharing_link
    mobile_map_url
  end

  def link
    [category_landing_link, permalink].join('/')
  end

  def mobile_link
    "/#{city.permalink}/#{preferred_category}s/#{permalink}"
  end

  def breadcrumbs
    bc = []

    bc << { :title => "Главная", :link => "/" }
    bc << { :title => preferred_categories[preferred_category], :link => category_landing_link }
    if network_landings.any?
      bc << { :title => network_landing.link_title, :link => network_landing.link }
    elsif specializations_landings.where(:city_id => city_id).any?
      bc << { :title => specialization_landing.link_title, :link => specialization_landing.link }
    end
    bc << { :title => category_with_title('i', true) }

    bc
  end

  def category_landing_link
    "#{'/msk' if city_id == 1}/#{preferred_category}s"
  end

  def preferred_categories
    {
      'restaurant' => "Рестораны #{city.name_r}",
      'cafe' =>       "Кафе #{city.name_r}",
      'bar' =>        "Бары #{city.name_r}",
      'club' =>       "Клубы #{city.name_r}"
    }
  end

  def reviews_with_4sq_count
    review_count <= 5 ? (review_count + external_reviews.foursquare.show.sorted.limit(10).count) : review_count
  end

  def stringify_features
    if tags.present?
      tags.split(', ').delete_if{|s| s.include?('бронирование') || s.include?('рублей')}.flatten.join(', ')
    else
      features.all(:conditions => ['kind in (?)', Feature::SPECIALIZATIONS]).map(&:title).join(', ')
    end
  end

  def full_description_features
    list = []
    permalinks = %w(breakfast business_lunch wifi parking child_menu)
    list << {
      permalink: 'cuisine',
      title: 'Кухня',
      value: features.kinds(:cuisine).map{|f| f.title.gsub(' кухня', '')}.join(', ')
    } if features.kinds(:cuisine).count == 1
    list << {
      permalink: 'cuisine',
      title: 'Кухни',
      value: features.kinds(:cuisine).map{|f| f.title.gsub(' кухня', '')}.join(', ')
    } if features.kinds(:cuisine).count > 1
    list << {
      permalink: 'subtype',
      title: 'Тип',
      value: features.kinds(:subtype).first.specialization
    } if features.kinds(:subtype).count > 0
    place_featutes_ids = features.where(permalink: permalinks).pluck(:id)
    Feature.where(permalink: permalinks).each do |f|
      item = {
        permalink: f.permalink,
        title: f.title,
        value: 'Нет' }
      if place_featutes_ids.include? f.id
        item[:value] = 'Да'
        item[:highlight] = true
      end
      list << item
    end
    list
  end

  def events_count
    events.future.limited.count
  end

  def full_company_name
    Agent::KIND.values.map{|v| contract_llc.to_s.include?("#{v} ")}.include?(true) ? contract_llc : "ООО «#{contract_llc}»"
  end

  def calculation_type
    if price_percent?
      "#{(revenue * 100).to_i}% от чека"
    elsif monthly_pay?
      "#{revenue} руб. в месяц"
    elsif revenue_type == 'person'
      "#{revenue} руб. за человека"
    else
      "#{revenue} руб. за стол"
    end
  end

  def afisha_url
    "http://www.afisha.ru/msk/#{afisha_kind || 'restaurant'}/#{afisha_id}/"
  end

  # old method, should be renewed with new features
  def actualization_date
    [ updated_at, timetable.updated_at, Date.new(2014,4,22).to_time ].compact.max
  end

  def page_title
    "#{category_with_title('i', true)} в #{city_name_p} #{(' на м. ' + metro_station.name) if metro_station}: отзывы, фото, адрес, меню"
  end

  def meta_title
    result = super.presence || page_title
    quantity = reviews.count
    if quantity >= 15
      result = "#{result} #{quantity} #{pluralize_review(quantity)}"
    end
    result
  end

  def meta_description
    result = super.presence || description
    result = "#{result} Закажите бесплатно столик в ресторане #{title} #{city_phone}"
    result
  end

  def rdfa_working_time
    str = smart_working_time('//') \
      .gsub(/ до последнего клиента/i, '- 24:00') \
      .gsub(/ с /i, ' ') \
      .gsub(/пн\./i, 'Mo') \
      .gsub(/вт\./i, 'Tu') \
      .gsub(/ср\./i, 'We') \
      .gsub(/чт\./i, 'Th') \
      .gsub(/пт\./i, 'Fr') \
      .gsub(/сб\./i, 'Sa') \
      .gsub(/вс\./i, 'Su') \
      .gsub(/ \– /i, '-') \
      .gsub(/, /i, ',')
    str.split('//')
  end

  def full_financial_conditions
    str = calculation_type
    str += ' + НДС' if vat
    str += ", #{banquet_percent * 100}% от #{banquet_from} человек" if banquet_from && banquet_percent
    str
  end

  def price_range
    price_ranges[0]
  end

  def landing_title
    network_landing.try(:link_title) || specialization_landing.try(:link_title)
  end

  def breadcrumbs_titles_length
    breadcrumbs.inject(0) { |memo, bc| memo + bc[:title].length }
  end

  def fin_alerts
    arr = []
    arr << "email для отчетов" if report_emails.blank?

    if by_cash?
      arr << "Оплата наличкой"
    else
      arr << "email для счетов" if invoice_emails.blank?
      arr << "Нет инфы по 1C" unless has_1c_uids?
    end

    if agent
      arr << "Имя по договору" if agent.ceo_short_name.blank?
    else
      arr << '!! Нет контрагента'
    end

    if contract
      arr << "Номер договора" if contract.number.blank?
      arr << "Дата договора" if contract.date.blank?
    else
      arr << '!! Нет договора'
    end


    arr << "Выручка" if revenue.blank? or revenue_type.blank?
    # arr << "Смешанная схема работы?" if fin_calculation_type == 'mixed'
    arr << "Ежемесячный платеж" if fin_calculation_type == 'monthly_pay'

    arr
  end

  def fin_calculation_type
    types = (partners.real.to_a.map{ |p| p.revenue_type } + [revenue_type]).uniq
    if monthly_pay_type?
      'monthly_pay'
    elsif types.include?('price_percent') and types.length > 1
      'mixed'
    elsif types.include?('price_percent') and types.length == 1
      'price_percent'
    else
      'fixed'
    end
  end

  # работает не точно нужно доработать поиск
  def pure_address
    pure_lvl_1 = ''

    address.split(',').each do |str|
      strs = str.strip.split(' ') - place_types_dictionary

      if strs.any? && strs.length < str.strip.split(' ').length
        pure_lvl_1 = strs.join(' ')
      end

    end

    max = address.split(',').group_by(&:size).max.last.first.strip
    max_str = max =~ /^[А-Я]/ ? max : ''

    match = pure_lvl_1.blank? ? max_str : pure_lvl_1

    pure_lvl_2 = match.split(' ') - numbers_dictionary
    pure_lvl_2.join(' ')
  end

  def place_types_dictionary
    @place_types_dictionary ||= begin
      place_types = []

      %w(ул наб пер пр-т пр-д пл бул б-р ш большая большой малая вал б пр м н пер-к).each do |type|
        place_types << type
        place_types << "#{type}."
        place_types << Unicode::capitalize(type)
        place_types << Unicode::capitalize("#{type}.")
      end

      (1..50).each do |index|
        place_types << "#{index}-ый"
        place_types << "#{index}-й"
        place_types << "#{index}-я"
        place_types << "#{index}-ой"
        place_types << "#{index}-ая"
      end

      place_types
    end
  end

  def numbers_dictionary
    @numbers_dictionary ||= begin
      arr = []
      (1..9).each do |dividend|
        (1..9).each do |divider|
          arr << "#{dividend}/#{divider}"
        end
      end

      (1..50).each do |index|
        arr << index.to_s
      end

      arr
    end
  end

  def avg_price_category
    case avg_price.to_i
    when 0..1500
      'to1500'
    when 1500..2500
      'to2500'
    else
      '2500plus'
    end
  end

  def last_financial_months_with_current
    months = financial_months.last_month.limit(6)
    month_start = Date.today.beginning_of_month.strftime("%Y-%m-%d")
    current_month = FinancialMonth.new(place_id: id, month_start: month_start)
    months.unshift(current_month)

    months
  end

  def report_emails_by_scope(place_scope)
    if Rails.env.production?
      emails = self.send(place_scope)
      if emails.any?
        emails + ['fin@gettable.ru']
      else
        txt = troubleshooting_emails_report[place_scope]
        FinancialNotifier.place_troubleshooting_emails(self, txt).deliver

        ['fin@gettable.ru']
      end
    else
      ['dima@gettable.ru']
    end
  end

  def troubleshooting_emails_report
    @troubleshooting_emails_report ||= begin
      {
        daily_report_emails: "Нет сотрудников для ежедневного отчета по броням.",
        invoice_emails: "Нет сотрудников для отчета по оплате.",
        report_emails: "Нет сотрудников для отчета по report_emails"
      }
    end
  end

  def general_promo_action(params)
    if params[:search]
      actions = self.promos.active.select([:id, :overlay_title, :overlay_description, :kind]).order('promos.id')
      promo = if (promos = actions.map(&:kind) & params[:search]) && promos.any?
        actions.find { |p| p.kind == promos.first }
      else
        actions.last unless params[:search].include?('birthday_discount')
      end

      promo
    end
  end

  def dedicated_phone_extended
    dp = dedicated_phone.present? ? dedicated_phone : place_group.try(:dedicated_phone)
    dp if dp.present?
  end

  def self.favorites_landing_subfeatures(user_counter)
    [{
      title: 'Нравится',
      specialization: 'Нравится',
      kind: 'mobile',
      text: user_counter,
      label: 'Нравится ' + user_counter.to_s + ' ' + Russian::pluralize(user_counter, 'другу', 'друзьям', 'друзьям') }]
  end

  def seo_title
    place_group.try(:common_title) ? title : category_with_title('i', true)
  end

end
