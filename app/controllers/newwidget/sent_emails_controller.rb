class Newwidget::SentEmailsController < Newwidget::BaseController

  before_action :set_booking
  after_action :update_booking_session

  def show
    if @booking.update(email: params[:email])
      if @booking.transferred? && @booking.can_send_confirm_email?
        Notifier.delay.deliver_booking(params[:email], @booking)
      end
      render json: { status: :ok }

    else
      render json: @booking.errors, status: :unprocessable_entity

    end
  end

  private

  def set_booking
    bookings = current_place.bookings.source(current_partner.source).states('paid', 'place_confirmed', 'cancelled')
    @booking = bookings.created_recently.widget(params[:widget]).first
  end

  def update_booking_session
    if response.status == 200 && cookies[:_b_session]
      session = $redis.hgetall("booking_session:#{cookies[:_b_session]}").symbolize_keys
      session[:user_email] = params[:email]

      $redis.mapped_hmset "booking_session:#{cookies[:_b_session]}", session
    end
  end

end
