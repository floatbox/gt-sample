object @place

attributes :id, :title, :iphone_booking_image_2x, :address

node(:url){ |pl| "https://gettable.ru#{pl.link}" }
