class Site::SocialController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    @social = cookies[cookie_key].nil? && cookies[cookie_key_permanent].nil?

    if @social

      unless cookies[cookie_key_counter].present?
        cookies[cookie_key_counter] = { value: 1, expires: 1.year.from_now, domain: :all }
      end

      cookies[cookie_key] = { value: true, expires: 1.year.from_now, domain: :all }

      @showing = cookies[cookie_key_counter]
    end
  end

  def update
    case params[:close]
    when 'once'
      counter = cookies[cookie_key_counter].to_i + 1
      cookies[cookie_key_counter] = { value: counter, expires: 1.year.from_now, domain: :all }
    when 'permanent'
      cookies.permanent[cookie_key_permanent] = { value: true, expires: 20.year.from_now, domain: :all }
      cookies.delete cookie_key_counter.to_sym
    end

    render :text => 'success'
  end

  def footer
    result = '<div class="page-footer__title">Мы в социальных сетях</div>
              <div class="soc">
                <a analytics-category="social_network_link"
                  analytics-event="footer/social/facebook/click"
                  analytics-on="click"
                  class="soc__fb"
                  href="https://www.facebook.com/gettable.ru" target="_blank">
                </a>
                <a analytics-category="social_network_link"
                  analytics-event="footer/social/vk/click"
                  analytics-on="click"
                  class="soc__vk"
                  href="http://vk.com/gettable" target="_blank">
                </a>
                <a analytics-category="social_network_link"
                  analytics-event="footer/social/instagram/click"
                  analytics-on="click"
                  class="soc__instagram"
                  href="https://instagram.com/gettable_ru/" target="_blank">
                </a>
              </div>'
    render text: result.html_safe
  end

  private

  def cookie_key
    "gt_social_#{params[:id]}".to_sym
  end

  def cookie_key_permanent
    "#{cookie_key}_permanent".to_sym
  end

  def cookie_key_counter
    "#{cookie_key}_counter".to_sym
  end

end
