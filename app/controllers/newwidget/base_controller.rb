class Newwidget::BaseController < ApplicationController

  helper :all
  layout "newwidget"

  before_action :redirect_mobile, if: :can_redirect_mobile?
  before_action :save_utm

  def current_partner
    @current_partner ||= Partner.find_by_source(params[:partner])
  end
  helper_method :current_partner

  def current_place
    @current_place ||= if Place::TEST_IDS.include? params[:place_id]
      Place.find params[:place_id]
    elsif params[:place_id].is_number?
      Place.production.find_by_id(params[:place_id]) || Place.soon.find_by_id(params[:place_id])
    end
  end
  helper_method :current_place

  def partner_phone?
    current_partner.phone?
  end
  helper_method :partner_phone?

  def timetable
    @timetable ||= current_place.timetable
  end
  helper_method :timetable

  def render *args
    add_retargeting
    super
  end

  private

  def redirect_mobile
    params[:redirect] = true
    params.delete(:subdomain)
    params.delete(:controller)
    params.delete(:action)
    partner = params.delete(:partner)
    place_id = params.delete(:place_id)

    redirect_to iphone_widget_url(partner, place_id, params)
  end

  def can_redirect_mobile?
    browser.mobile? && !current_partner.has_children? && !current_partner.parent
  end

end
