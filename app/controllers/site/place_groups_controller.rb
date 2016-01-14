class Site::PlaceGroupsController < Site::BaseController

  def index
    @place_groups = current_city.place_groups.by_position.limit(12)
  end

end
