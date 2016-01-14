module IphoneWelcomePageTemplateService
  extend self

  A_B_COMMON_TEMPLATES = %w(common_winter_a common_winter_b)

  def a_b_popup_common
    a_b_popup(A_B_COMMON_TEMPLATES)
  end

  def pick(resource = nil)
    "m/pages/popups/#{pick_for_resource(resource)}"
  end

  def pick_for_resource(resource)
    case resource.class.name
    when 'Place'
      pick_for_place(resource)
    end.presence || a_b_popup_common
  end

  # в зависимости от типа заведения возвращаем определенную заглушку
  # Приоритеты
  # 1. Фейк
  # 2. Сеть
  # 3. Специализация
  # 4. Все остальные
  def pick_for_place(place)
    if place.fake?
      'fake'
    elsif place.features.pluck(:id).include?(199) && Date.today <= Date.new(2015, 10, 31)
      'halloween'
    elsif [2, 77, 81].include?(place.place_group_id)
      # ищу если есть соответствующи place_group_id
      # 2 - Ginza Project; 77 - ДжонДжоли; 81 - Чайхона;

      case place.place_group.permalink
      when 'jon_joli'
        'jon_joli'
      when 'chaihona_loungecafe'
        'chaihona_loungecafe'
      when 'ginza'
        'ginza'
      end

    elsif place.specializations.any? && spec_ids = place.specializations.pluck(:id)
      # проверяю насичие соответствующего specialization по feature id
      # 19 - Панорамный вид; 34 - Рыбный ресторан; 36 - Грузинский ресторан;
      # 25 - Русская ресторан; 40 -Японский ресторан; 28 - Итальянский ресторан;

      if spec_ids.include?(19)
        'great_view'
      elsif spec_ids.include?(34)
        'cuisine_fish'
      elsif spec_ids.include?(36)
        'cuisine_georgian'
      elsif spec_ids.include?(25)
        'cuisine_russian'
      elsif spec_ids.include?(40)
        'cuisine_japan'
      elsif spec_ids.include?(28)
        'cuisine_italian'
      end
    else
      a_b_popup_common
    end
  end

  private

  def a_b_popup templates
    length = templates.length
    length > 1 ? templates[rand(length)] : templates[0]
  end

end
