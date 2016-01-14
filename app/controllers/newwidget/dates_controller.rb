class Newwidget::DatesController < Newwidget::BaseController

  def index
    date_kind = partner_phone? ? 'mobile' : 'common'
    booking_date = current_place.get_booking_date

    @dates = Timetable.cool_dates(booking_date, date_kind).map do |date|
      OpenStruct.new date.merge( { datetime: date[:date].to_datetime } )
    end
  end

end
