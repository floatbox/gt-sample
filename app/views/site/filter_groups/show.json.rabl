object @filter_group

attributes :title, :value
node :filters, :object_root => false do |filter_group|
  sf = filter_group.search_filters.where.not(value: ["valentine's day"])
  if @landing.present?
    excludes = @landing.search_filters.map(&:value)
    sf = sf.delete_if{ |s| excludes.include?(s.value) }
  end
  sf.map { |sf| partial("site/search_filters/show", :object => sf) }
end
