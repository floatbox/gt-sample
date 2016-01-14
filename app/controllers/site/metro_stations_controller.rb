class Site::MetroStationsController < Site::BaseController

  def index
    @metro_stations = current_city.metro_stations.sorted
  end

end
