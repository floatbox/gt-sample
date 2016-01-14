object @menu_item

attributes :name

node(:price_text){ |mi| mi.price_text || mi.price }
