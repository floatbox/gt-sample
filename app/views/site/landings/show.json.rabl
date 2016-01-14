object @landing

attributes :id, :kind

node(:seo_description_presence) { |l| l.landing_description? }

child :search_filters do
  extends "site/search_filters/show"
end
child :filter_groups do
  extends "site/filter_groups/show"
end
