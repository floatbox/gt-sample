class Site::SitemapController < Site::BaseController

  def index
    landings = current_city.site_landings

    @filters = landings.common
    @metro = landings.metro
    @cuisine = landings.cuisine
    @network = landings.network
    @categories = %w(Бары Рестораны Клубы Кафе).map do |category|
      title = "#{category} #{current_city.name_r}"

      SiteLanding.find_by_link_title(title)
    end
  end

end
