class AfishaPhoto < ActiveRecord::Base
  
  belongs_to :place
  validates_presence_of :place, :url, :afisha_photo_id
  
  named_scope :visible, :conditions => 'visible = true'
  named_scope :sorted, :order => 'position asc'
  
  def landing
    url
  end
  
end