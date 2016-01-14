class PartnerUser < User
  belongs_to :partner
  
  before_validation_on_create :set_role
  default_scope :conditions => ['users.role = ?', 'partner']

private
  def set_role
    self.role = 'partner'

    true
  end
  
end