class Newwidget::PlacesController < Newwidget::BaseController

  def index
    if params[:partner].to_s == 'afisha'
      @places = Place.production.afisha.to_a
    else
      @places = Place.production.to_a
    end

    render :file => "newwidget/places/index", :layout => false
  end

end
