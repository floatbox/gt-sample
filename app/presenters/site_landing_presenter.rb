module SiteLandingPresenter
  include Site::LandingsHelper

  def meta_title
    result = super.presence || "#{title}. Gettable – лучшие рестораны города"
    result += " Нашлось #{places_count} #{pluralize_place(places_count)}." if kind == 'landing'
    result
  end

  def meta_description
    result = super.presence || "#{description}"
    if kind == 'landing'
      quantity = reviews_count
      result = "#{result} #{quantity} #{pluralize_review(quantity)}! Закажите бесплатно столик #{city_phone}."
    end
    result
  end

  def link
    permalink
  end

  def full_link
    "https://#{city.permalink + '.' unless city_id == 1}gettable.ru#{link}"
  end

  def mobile_link
    if permalink.include?(city.permalink)
      permalink
    else
      "#{city.permalink}#{permalink}"
    end
  end

end
