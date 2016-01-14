class Newwidget::SmsesController < Newwidget::BaseController

  def send_code
    @pc = Sms::BookingConfirmation.create do |it|
      it.phone = params[:phone].include?('+7') ? params[:phone] : "+7#{params[:phone]}"
      it.widget = params[:widget]
      it.mobile = current_partner.phone?
    end

    render 'newwidget/smses/send_code.json', :layout => false
  end

  def check_code
    unless @confirmation
      @confirmation = Sms::BookingConfirmation.phone(booking_phone).live(params[:booking][:widget]).sorted.first
    end

    if @confirmation
      @confirmation.check(params[:booking][:code])
      @confirmation.confirmed? ? create : set_error("Неверный код")
    else
      bugsnag_code_out_of_date
      set_error("Ваш код устарел, отправьте новый код")
    end

    render 'newwidget/smses/check_code.json', :layout => false
  end

  def create
    @booking = Booking.new(booking_params)

    @booking.phone = booking_phone

    if @booking.save

      if @booking.promo
        promo_value = if cookies[:promo].present?
          cookies[:promo].split(',').push(@booking.promo).uniq.join(',')
        else
          @booking.promo
        end

        cookies[:promo] = {
          :value => promo_value,
          :domain => :all,
          :expires => 20.years.from_now.utc
        }
      end

      set_booking_session(@booking)

    else

      set_error(@booking.errors)

    end
  end

  private

  def booking_phone
    params[:booking][:phone].include?('+7') ? params[:booking][:phone] : "+7#{params[:booking][:phone]}"
  end

  def set_error(txt)
    @error = txt
  end

  def bugsnag_code_out_of_date
    old_confirmation = Sms::BookingConfirmation.phone(booking_phone).widget(params[:booking][:widget]).sorted.first

    created_ago = if old_confirmation
      ((Time.zone.now - old_confirmation.created_at).to_i / 60 ).to_s + 'min ago.'
    else
      'unknown'
    end

    Bugsnag.notify(RuntimeError.new("Sms code out of date"), { phone: booking_phone,
                                                               widget: params[:booking][:widget].split('-').first,
                                                               created_ago: created_ago } ) if Rails.env.production?
  end

  def booking_params
    params.require(:booking).permit(
      :persons, :place_id, :phone, :name, :source, :widget, :user_comment, :time, :time_state, :promo
    ).merge(
      allow_transfer: false,
      utm_source: session[:utm_source],
      utm_content: session[:utm_content],
      utm_campaign: session[:utm_campaign]
    )
  end

  def set_booking_session(booking)
    if response.status == 200
      cookies.permanent[:_b_session] = uuid
      $redis.mapped_hmset "booking_session:#{uuid}", booking_session(booking)
    end
  end

  def uuid
    @uuid ||= cookies[:_b_session] || UUIDTools::UUID.random_create.to_s
  end

  def booking_session(booking)
    {
      user_name: booking.name,
      user_phone: booking.phone,
      last_booking: booking.place_id,
      is_mobile: partner_phone?
    }
  end

end
