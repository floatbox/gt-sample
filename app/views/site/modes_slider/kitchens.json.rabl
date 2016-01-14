object false

node(:kitchen) do
  @kitchens.map do |kitchen|
    {
      href: kitchen[:href],
      image: asset_url(kitchen[:image]),
      title: kitchen[:title],
    }
  end
end

node(:feature) do
  @features.map do |kitchen|
    {
      href: kitchen[:href],
      image: asset_url(kitchen[:image]),
      title: kitchen[:title],
    }
  end
end
