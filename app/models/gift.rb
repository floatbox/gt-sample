class Gift < ActiveRecord::Base
  extend Enumerize

  KINDS = ['taxi', 'plain', 'cinema', 'theatre', 'iphone', 'dinner', 'discount', 'qlean', 'place']
  DELIVERY_TYPES = ['code', 'pdf']

  enumerize :kind, :in => KINDS, :predicates => true
  enumerize :delivery_type, :in => DELIVERY_TYPES, :predicates => true

  has_many :gift_items
  belongs_to :city
  belongs_to :place

  validates :title, :emoji, presence: true
  validates :delivery_type, :presence => true, :inclusion => { :in => DELIVERY_TYPES }
  validates_inclusion_of :kind, :in => KINDS

  scope :for_place, -> { where(kind: 'place') }

end
