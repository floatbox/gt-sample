class ExternalUser < ActiveRecord::Base
  belongs_to :user
  
  def self.by_auth(auth)
    self.first(:conditions => { :provider => auth['provider'],
                                :uid      => auth['uid'].to_s })
  end
end
