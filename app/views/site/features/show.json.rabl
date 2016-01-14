object @feature

attributes :id, :title

child(root_object.city_landings(@place.city_id) => :landings){ attributes :title, :link }
