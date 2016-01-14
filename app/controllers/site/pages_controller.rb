class Site::PagesController < Site::BaseController
  include CommonPagesMethods

  before_action :redirect_mobile, if: :can_redirect_mobile?

  private

  def redirect_mobile
    redirect_to subdomain: 'm'
  end

  def can_redirect_mobile?
    browser.mobile? && (params[:page].nil? || page_has_mobile_version?)
  end

  def page_has_mobile_version?
    %w(index).include?(params[:page])
  end

end
