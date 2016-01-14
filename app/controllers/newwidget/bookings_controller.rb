class Newwidget::BookingsController < Newwidget::BaseController

  before_action :set_retargeting, :set_widget, only: :show

  def show
    @booking_hash = {
      place_id: params[:place_id],
      promo: params[:promo],
      source: current_partner.source,
      partner: place_group,
      close_button: !current_partner.facebook? && current_partner.close_button,
      widget: @widget
    }

    if params[:time] && params[:persons]
      @booking_hash[:present_value] = {
        time: params[:time],
        persons: params[:persons]
      }
    end
  end

  def check
    render :text => 'success'
  end

  def stop_link
    render :text => 'close'
  end

  private

  def set_retargeting
    @retargeting = {
      "pagetype" => "rest",
      "pcat" => "step1"
    }
  end


  def set_widget
    5.times do |i|
      @widget = UUIDTools::UUID.random_create.to_s
      break if Booking.widget(@widget).empty?
    end
  end

  def place_group
    if current_partner && current_partner.children.any?
      partner_places = current_partner.children.pluck(:referable_id)
      place_count = Place.production.where(id: partner_places).count

      if place_count
        place_group = current_partner.referable
        count = "#{place_count} #{Russian::pluralize(place_count, 'заведение', 'заведения', 'заведений')}"
        children = current_partner.children.includes(:referable).map do |child|
          if child.referable && child.referable.active? && child.referable.place_group_id.to_i == place_group.id
            {
              title: child.referable.title,
              place_id: child.referable_id,
              partner_id: child.source,
              place_type: child.referable.preferred_category,
              place_check: child.referable.avg_price_category
            }
          end
        end.compact.sort{|a, b| a[:title] <=> b[:title]}

        {
          place_group: place_group.title,
          place_count: count,
          children: children
        }
      end
    end
  end

end
