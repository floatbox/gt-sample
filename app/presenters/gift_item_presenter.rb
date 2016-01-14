module GiftItemPresenter
  def replace_date_templates text
    result = text.dup
    if from = try(:started_at)
      from = from.strftime("%d-%m-%Y")
      result.gsub!(/%from%/, from)
    end

    if to = try(:expiry_at)
      to = to.strftime("%d-%m-%Y")
      result.gsub!(/%to%/, to)
    end
    result
  end
end