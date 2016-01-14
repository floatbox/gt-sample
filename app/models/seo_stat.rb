class SeoStat < ActiveRecord::Base
  extend ActsAsXlsx

  acts_as_xlsx unless Rails.env.test?

  before_create :fill

  private

  def fill
    self.places_active = Place.production.count
    self.place_our_reviews = Place.with_our_review.count
    self.place_short_descriptions = Place.with_short_description.count
    self.place_full_descriptions = Place.with_full_description.count
    self.place_meta_titles = Place.with_meta_title.count
    self.place_meta_descriptions = Place.with_meta_description.count
    self.landings_active = SiteLanding.count
    self.landing_landing_descriptions = SiteLanding.with_landing_description.count
    self.landing_meta_titles = SiteLanding.with_meta_title.count
    self.landing_meta_descriptions = SiteLanding.with_meta_description.count
  end
end
