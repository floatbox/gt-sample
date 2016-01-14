class PlaceGroup < ActiveRecord::Base
  include AssociationsPlaceReindex

  acts_as_list

  belongs_to :parent, :class_name => 'PlaceGroup', :foreign_key => :parent_id, :inverse_of => :children

  has_many :city_place_groups, :dependent => :destroy
  has_many :cities, :through => :city_place_groups
  has_many :children, :class_name => 'PlaceGroup', :foreign_key => :parent_id, :inverse_of => :parent
  has_many :partners, :as => :referable
  has_many :call_records

  has_attached_file :logo, { :styles => { :main => ['213x213#', 'png'] },
                                          :path => "place_groups/:id/:style.png" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates_presence_of :title
  validates_uniqueness_of :permalink

  validates_attachment_content_type :logo, :content_type => /image/, :allow_blank => true

  named_scope :global, :conditions => { :global => true }
  named_scope :sorted, :order => 'title asc'
  named_scope :by_position, :order => 'position asc'
  named_scope :without_childrens, :conditions => { :parent_id => nil }

  after_create  :add_search_filter
  after_destroy :remove_search_filter

  def places
    Place.scoped(:conditions => ['place_group_id in (?)', [id] + children.to_a.map(&:id)])
  end

  def add_search_filter
    SearchFilter.create(:kind => "place_group", :value => "network_#{id}", :title => title, :short_title => title)
  end

  def remove_search_filter
    SearchFilter.first(:conditions => {:kind => "place_group", :value => "network_#{id}"}).delete
  end

  def logo_url
    logo.url(:main)
  end

  def resto_count(city)
    places.where(:city => city).production.count
  end

  def parent_title
    parent.try(:title)
  end

  def landing_link(city)
    "#{'/msk' if city.id == 1}/network/#{permalink}"
  end

end
