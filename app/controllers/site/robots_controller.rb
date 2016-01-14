class Site::RobotsController < Site::BaseController
  layout false

  def show
    render file: "site/robots/#{filename}.text", content_type: 'text/plain'
  end

  private

  def filename
    case
    when request.host == 'betadeposit.ru'
      'disallow'
    when first_subdomain.present? && first_subdomain == 'm'
      'mobile'
    when City::ACTIVE.include?(first_subdomain)
      'city'
    when first_subdomain.present?
      'disallow_with_host'
    else
      'city'
    end
  end

  def first_subdomain
    @first_subdomain ||= request.subdomains.first
  end

end
