class Newwidget::SpecialTermsController < Newwidget::BaseController

  def show
    @tags = timetable.special_info_tags
    @html = special_terms_html
  end

  private

  def special_terms_html
    render_to_string(
      layout: false,
      partial: "special_term.html",
      locals: {
        place: current_place,
        description: timetable.special_description,
        where: timetable.special_info_where
      }
    )
  end

end
