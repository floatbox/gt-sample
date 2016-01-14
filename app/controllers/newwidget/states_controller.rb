class Newwidget::StatesController < Newwidget::BaseController

  def show
    @nearest_time = timetable.nearest_booking_time(date, false, 15)
  end

  private

  def date
    @date ||= params[:date] ? params[:date].to_date : current_place.get_booking_date
  end

end
