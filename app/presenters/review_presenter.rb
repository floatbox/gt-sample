module ReviewPresenter
  
  def translated_impression
    case impression
    when 'like'
      "Понравилось"
    when 'dislike'
      "Не понравилось"
    when 'didnotgo'
      "Не ходил"
    end
  end
  
end