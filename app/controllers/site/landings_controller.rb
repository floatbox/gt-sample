class Site::LandingsController < Site::BaseController

  before_action :set_landing
  before_action :redirect_mobile, if: -> { browser.mobile? }

  def show
  end

  def current_landing
    @landing
  end
  helper_method :current_landing

  private

  def set_landing
    @landing = SiteLanding.find(params[:id])
  end

  def redirect_mobile
    host = request.host_with_port.gsub(/[a-z0-9\-.]*(gettable|bardeposit|betadeposit)/, 'm.\1')

    redirect_to "#{request.protocol}#{host}#{@landing.mobile_link}?#{request.query_string}"
  end

end
