class Site::PlacesController < Site::BaseController

  before_action :set_place, only: :show
  before_action :redirect_mobile, only: :show, if: -> { browser.mobile? }
  before_action :redirect_if_inactive, only: :show
  before_action :add_retargeting, only: :show

  def index
    Place.paginates_per paginates_per

    @places = if params[:title].present?
      Place.es_observer(query: params[:title], city_id: current_city.id)
    elsif params[:similar_id].present?
      Place.find(params[:similar_id]).similar
    else
      filtered_places
    end

    if params[:map].present?
      @places = PlaceCluster.new(@places.per(1000).records, map_rectangular).filtered_places

      render "locations"
    else
      @places = @places.page(params[:page])

      response.headers['LAST_PAGE'] = @places.last_page?.to_s
      response.headers['TOTAL_PLACES'] = @places.total_count.to_s

      @places = @places.records.includes(:timetable)
    end
  end

  def show
  end

  def current_place
    @place
  end
  helper_method :current_place

  private

  def set_place
    @place = Place.not_demo.find(params[:id])
  end

  def filtered_places
    criteria = SearchFilter.es_serialize(params[:search] || {})

    criteria[:city_id] = current_city.id
    criteria[:center] = false if params[:map] && criteria[:center]

    Place.es_filter(criteria)
  end

  def map_rectangular
    opts = JSON.parse(params[:map])
    [
      [ opts["top_left"]["lon"].to_f, opts["bottom_right"]["lon"].to_f ].sort,
      [ opts["top_left"]["lat"].to_f, opts["bottom_right"]["lat"].to_f ].sort
    ]
  end

  def paginates_per
    case params[:paginates_per]
    when 'discount_10perc', 'resto_present_aug_2015'
      Place.includes(:features).where('features.id IN (?)', feature_ids).references(:features).size
    else
      10
    end
  end

  def feature_ids
    SearchFilter.find_by_value(params[:paginates_per]).features.pluck(:id)
  end

  def redirect_if_inactive
    redirect_to root_url if @place.fake
  end

  def redirect_mobile
    host = request.host_with_port.gsub(/[a-z0-9\-.]*(gettable|bardeposit|betadeposit)/, 'm.\1')

    redirect_to "#{request.protocol}#{host}#{@place.mobile_link}?#{request.query_string}"
  end

end
