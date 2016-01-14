class Site::TopBannerController < ApplicationController
  def mobile_app_link
    sms = Sms::Sms.mobile_app_link(params[:phone_number])
    if sms.error_description
      render json: { error: sms.sms.error_description }
    else
      render json: { state: sms.state }
    end
  end
end
