class LotteryService

  START_STEPS = 1
  MAX_START_LOYALTY_STEPS = 3
  GIFT_FREQ = 7
  GIFT_SLOTS = 3

  def initialize(user)
    @user = user
  end

  def first_step!
    if @user.phone && @user.next_gift_steps.nil?
      @user.update_attribute(:next_gift_steps, GIFT_FREQ)
      user_confirmed_bookings = @user.bookings.revise_confirmed.count
      start_steps = user_confirmed_bookings > MAX_START_LOYALTY_STEPS ? MAX_START_LOYALTY_STEPS : user_confirmed_bookings
      if start_steps > 0 && false
        return give_loyalty_steps(start_steps)
      else
        return give_start_step
      end
    end
  end

  def give_loyalty_steps(start_steps)
    @user.bookings.revise_confirmed.earlier.last(start_steps).each do |b|
      b.add_user_step
    end
    OpenStruct.new({kind: 'loyalty', amount: @user.steps_sum})
  end

  def give_start_step
    @user.make_step( kind: 'start', amount: 1)
  end

  def give_ny_step
    @user.make_step( kind: 'ny2015', amount: 1)
    steps_to_gift = @user.next_gift_steps - @user.steps_sum
    if steps_to_gift > 0
      @user.send_push!("Бонусный балл в подарок на Новый Год! 🎄 До приза осталось #{steps_to_gift} шагов", { link: 'gettable://bonus/' })
    else
      @user.send_push!('Бонусный балл в подарок на Новый Год! 🎄 Заберите свой приз', { link: 'gettable://bonus/' })
    end
  end

  def user_win?
    return false if get_win.nil?
    @user.next_gift_steps && @user.steps_sum >= @user.next_gift_steps
  end

  def process!
    if user_win?
      win = get_win
      present!(win)
      {
        win: win,
        slots: get_slots(win)
      }
    end
  end

  def clear_restart!
    @user.gift_items.update_all("user_id = NULL, step_level = NULL, presented_at = NULL")
    @user.steps.destroy_all
    @user.update_attribute(:next_gift_steps, nil)
  end

  def restart!
    @user.update_attribute(:next_gift_steps, nil)
  end

  private

  def present!(win)
    win.give_to_user(@user)
    set_next_gift_steps
  end

  def get_win
    given_places_gift_ids = @user.gift_items.for_places.pluck(:gift_id)
    GiftItem.joins(:gift).where.not(gift_id: given_places_gift_ids).where('min_steps < ?', @user.steps_sum).where('gifts.city_id IS NULL OR gifts.city_id = ?', @user.city_id).free.order("RANDOM()").readonly(false).first
  end

  def get_slots(win)
    gifts = Gift.where('id <> ?', win.gift_id).order("RANDOM()").limit(GIFT_SLOTS-1)
    gifts << win.gift
  end

  def set_next_gift_steps
    @user.increment!(:next_gift_steps, GIFT_FREQ)
  end

end
