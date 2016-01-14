class Filter < ActiveRecord::Base

  named_scope :sorted, :order => 'position asc'

end