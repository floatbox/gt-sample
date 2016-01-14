class Landing < ActiveRecord::Base
  extend ActsAsXlsx

  acts_as_xlsx unless Rails.env.test?

  belongs_to :city
  belongs_to :filter_group_set
  belongs_to :parent, class_name: 'Landing'

  has_many :filter_groups, through: :filter_group_set
  has_many :landing_filters
  has_many :search_filters, through: :landing_filters

  validates_presence_of :city, :title

  scope :msk,    -> { where(city_id: 1) }
  scope :sorted, -> { order(:position) }
  scope :visible,   -> { where(visible: true) }

  # TODO Заменил на прямое обращение к SearchFilter
  def places
    search_filters.map { |sf| sf.es_places(city_id) }.flatten
  end

  def places_count
    places.count
  end

  def reviews_count
    result = places.map(&:id)
    result = Place.includes(:reviews).find(result)
    result.inject(0){ |sum, place| sum + place.reviews.length }
  end

  def to_label
    "#{title} (#{city.name})"
  end

  def property
    link =~ /cuisine/ ? 'servesCuisine' : ''
  end
end
