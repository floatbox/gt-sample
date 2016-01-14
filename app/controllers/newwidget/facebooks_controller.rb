class Newwidget::FacebooksController < ApplicationController
  protect_from_forgery except: :create

  def create
    if page_id && (partner = Partner.facebook_page(page_id).first)
      redirect_to_booking(partner)
    elsif data && data["page"] && data["page"]["id"] && (partner = Partner.facebook_page(data["page"]["id"]).first)
      redirect_to_booking(partner)
    else
      raise ActionController::RoutingError, 'Not Found'
    end
  end

  private

  def data
    @date ||= begin
      parse_signed_request params[:signed_request].to_s if params[:signed_request]
    end
  end

  def page_id
    @page_id ||= begin
      params[:tabs_added].keys.first if params[:tabs_added]
    end
  end

  def redirect_to_booking(partner)
    redirect_to url_for controller: 'bookings', action: 'show', partner: partner.source, place_id: partner.referable_id, protocol: 'https'
  end

  def parse_signed_request(request, secret_id = '4ccf61913e769e7cad78dc3e3c1f4a79')
    encoded_sig, payload = request.split('.', 2)
    sig = urldecode64(encoded_sig)
    data = JSON.parse(urldecode64(payload))
    if data['algorithm'].to_s.upcase != 'HMAC-SHA256'
      raise "Bad signature algorithm: %s" % data['algorithm']
    end
    expected_sig = OpenSSL::HMAC.digest('sha256', secret_id, payload)
    if expected_sig != sig
      raise "Bad signature"
    end
    data
  end

  def urldecode64(str)
    encoded_str = str.tr('-_', '+/')
    encoded_str += '=' while !(encoded_str.size % 4).zero?
    Base64.decode64(encoded_str)
  end

end
