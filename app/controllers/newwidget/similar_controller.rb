class Newwidget::SimilarController < Newwidget::BaseController

  def index
    Place.paginates_per 3

    @places = Place.find(params[:place_id]).similar_available(params[:date].to_date)
  end

end
