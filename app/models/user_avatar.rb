class UserAvatar < ActiveRecord::Base

  belongs_to :user
  belongs_to :avatar

  scope :opened, -> { where.not(open_at: nil) }
  scope :closed, -> { where(open_at: nil) }

  def open!
    update_attributes(open_at: Time.zone.now)
  end

  def open?
    open_at.present?
  end

  def self.check_to_open(user)
    uas = where(user: user).closed.joins(:avatar).where('user_avatars.achievement_value >= avatars.achievement_price').readonly(false)
    uas.collect{|ua| ua.avatar}
  end
end
