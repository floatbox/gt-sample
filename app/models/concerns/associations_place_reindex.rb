module AssociationsPlaceReindex
  extend ActiveSupport::Concern

  included do
    after_save :update_place_document
    after_destroy :update_place_document
  end

  private

  def update_place_document

    update_document if defined?(place) && place.present?

    update_documents if defined?(places) && places.present?

  end

  def update_document
    reindex(place.id)
  end

  def update_documents
    places.pluck(:id).each do |place_id|
      reindex(place_id)
    end
  end

  def reindex(place_id)
    Place.find(place_id).__elasticsearch__.index_document
  end

end
