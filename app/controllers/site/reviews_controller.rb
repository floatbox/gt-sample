class Site::ReviewsController < Site::BaseController
  before_action :get_place, only: [ :index, :show ]

  def index
    @reviews = @place.reviews.includes(:booking).moderated.visited.with_description.bub_sorted(params[:sort_review_id]).page(params[:page]).per(10).padding(params[:offset])
  end

  def new
    @booking = Booking.find_by widget: params[:widget]
    if @booking && @booking.mail_sign == params[:sign]
      @review = @booking.review || @booking.create_review(impression: params[:impression])
      @review.description = nil
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def update
    @booking = Booking.find_by widget: params[:review][:widget]
    if (@review = @booking.review) && @review.description.nil?
      @review.update(description: params[:review][:description])
    end
    @impression = params[:review][:impression]
  end

  private

  def get_place
    @place = current_city.places.not_demo.find params[:place_id]
  end

end
