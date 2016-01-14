class Hierclust::Point
  attr_accessor :data
end

class PlaceCluster
  attr_accessor :filtered_places, :separation, :resolution, :x1, :x2

  def initialize(places, rect)
    expand_rate = 0.1
    x1, x2, y1, y2 = rect.flatten

    @separation = (x2 - x1) / 7
    @resolution = (x2 - x1) / 3
    @without_clusters = x2 - x1 < 0.02

    @filtered_places = places.where(['longitude BETWEEN ? and ? and latitude BETWEEN ? and ?',
     x1 - (x2 - x1) * expand_rate, x2 + (x2 - x1) * expand_rate,
     y1 - (y2 - y1) * expand_rate, y2 + (y2 - y1) * expand_rate]).select(
      :id, :longitude, :latitude, :title, :preferred_category, :avg_price
    )
  end

  def clusters
    if @filtered_places.size < 20 || @without_clusters
      serialized_places
    else
      calc_clusters
    end
  end

  private

  def serialized_places
    filtered_places.map { |pl| { :place => pl.basic_serialization } }
  end

  def points
    filtered_places.map do |place|
      point = Hierclust::Point.new(place.longitude, place.latitude)
      point.data = place

      point
    end
  end

  def calc_clusters
    @clusterer = Hierclust::Clusterer.new(points, separation, resolution)
    @clusterer.clusters.map do |cluster|

      if cluster.points.count < 6

        cluster.points.map { |pnt| { :place => pnt.data.basic_serialization } }

      else

        {
          :cluster => {
            :longitude => cluster.x,
            :latitude => cluster.y,
            :count => cluster.points.count
          }
        }

      end

    end.flatten
  end

end
