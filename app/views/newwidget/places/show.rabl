object @place

attributes :id, :title, :address, :latitude, :longitude
attributes :landing_link => :link, :city_name => :city

node(:created_at){ |p| p.created_at.to_date.strftime("%d.%m.%Y") }
