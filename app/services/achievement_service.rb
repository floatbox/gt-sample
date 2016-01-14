class AchievementService

  def initialize(booking)
    @booking = booking
    @user = booking.user
    @place = booking.place
  end

  def process!
    process_booking!
    process_features!
    process_network!
  end

  def self.login!(user)
    Avatar.badge.login_achievement.each do |a|
      ua = a.user_avatars.find_or_create_by(user: user)
      ua.increment!(:achievement_value)
    end
  end


  private

  def process_booking!()
    Avatar.badge.booking_achievement.each do |a|
      ua = a.user_avatars.find_or_create_by(user: @user)
      ua.increment!(:achievement_value)
    end
  end

  def process_features!()
    pf_ids = @place.place_features.pluck(:feature_id)
    Avatar.badge.feature_achievement.each do |a|
      if pf_ids.include? a.achievement_key.to_i
        ua = a.user_avatars.find_or_create_by(user: @user)
        ua.increment!(:achievement_value)
      end
    end
  end

  def process_network!()
    network_id = @place.place_group_id
    Avatar.badge.network_achievement.each do |a|
      if network_id == a.achievement_key.to_i
        ua = a.user_avatars.find_or_create_by(user: @user)
        ua.increment!(:achievement_value)
      end
    end
  end

end
