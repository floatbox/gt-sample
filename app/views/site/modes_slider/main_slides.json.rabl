object false

node(:slides) do
  @slides.map do |slide|
    {
      title: slide[:title],
      description: slide[:description],
      link_href: slide[:link_href],
      link_title: slide[:link_title],
      image: asset_url(slide[:image]),
      background: asset_url(slide[:background])
    }
  end
end
