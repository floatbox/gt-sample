class Newwidget::BookingPlacesController < Newwidget::BaseController
  before_action :check_last_booking

  private

  def check_last_booking
    if uuid = cookies[:_b_session]
      if (hash = $redis.hgetall("booking_session:#{uuid}").symbolize_keys) && hash[:user_phone]
        hash[:user_phone] = hash[:user_phone].last(10)

        @last_booking = hash
      end
    end
  end

end
