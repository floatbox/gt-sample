class Site::BaseController < ApplicationController
  before_action :save_utm
  before_action :refresh_user_session

  layout 'site'

end
