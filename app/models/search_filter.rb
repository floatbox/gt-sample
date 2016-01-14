class SearchFilter < Filter
  extend SearchFilterPresenter
  KINDS = %w(price cuisine feature special place_group until_late center metro mode
             category birthday_discount with_likes latest working_day popular)

  acts_as_list

  has_many :features, through: :filter_features
  has_many :filter_features, dependent: :destroy
  has_many :filter_group_filters, dependent: :destroy
  has_many :filter_groups, through: :filter_group_filters
  has_many :landing_filters
  has_many :landings, through: :landing_filters
  has_many :tagged_items, as: :item, dependent: :destroy
  has_many :tags, through: :tagged_items

  accepts_nested_attributes_for :filter_features, allow_destroy: true

  has_attached_file :icon, { styles: { main: ['47x36#', 'jpg'] },
                             path: 'search_filters/:id/:style.jpg'
                            }.merge(PAPERCLIP_STORAGE_OPTIONS)
  has_attached_file :photo, { styles: { main: ['320x140#', 'png'],
                                        main_2x: ['640x280#', 'png'],
                                        main_3x: ['960x420#', 'png'],
                                        preview: ['32x14#', 'png'],
                                        preview_2x: ['64x28#', 'png'],
                                        preview_3x: ['96x42#', 'png'] },
                            path: "trends/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)

  has_attached_file :mobile_icon,
                    { styles: { show:    ['48x48#',   'png'],
                                show_2x: ['72x72#', 'png'],
                                show_3x: ['144x144#', 'png'] },
                      path: 'search_filters/:id/mobile_icon/:style.png'
                      }.merge(PAPERCLIP_STORAGE_OPTIONS)

  validates :title, :short_title, :kind, presence: true
  validates :date_to, presence: true, if: :date_from
  validates :value, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validates_attachment_content_type :icon, content_type: /image/, allow_blank: true
  validates_attachment_content_type :photo, content_type: /image/, allow_blank: true
  validates_attachment_content_type :mobile_icon, content_type: ["image/png"], allow_blank: true

  scope :kind,   ->(kind) { where(kind: kind) }
  scope :sorted, -> { order(position: :asc) }
  scope :active, -> { where('date_from is NULL or (date_from <= :date and date_to >= :date)', date: Date.today) }

  # Predicates

  def place_group?
    kind == 'place_group'
  end

  def metro?
    kind == 'metro'
  end

  # Shortcuts

  def metro_station
    MetroStation.find value.gsub(/metro_/, '') if metro?
  end

  def place_group
    PlaceGroup.find value.gsub(/network_/, '') if place_group?
  end

  # ElasticSearch

  def es_params
    send("es_#{kind}_parametrize".to_sym)
  end

  def es_cuisine_parametrize
    es_feature_parametrize
  end

  def es_feature_parametrize
    current_filter_features
  end

  def es_price_parametrize
    case value
    when 'price_p'
      { min: 0, max: 1_500 }
    when 'price_pp'
      { min: 1_500, max: 2_500 }
    when 'price_ppp'
      { min: 2_500, max: 1_000_000 }
    end
  end

  def es_until_late_parametrize
    time = Time.zone.now

    now = time.strftime('%k').to_f + time.strftime('%M').to_f / 60
    case
    when now < 4.5
      day = (time - 1.day).strftime('%w')
      close = now + 24 + 1.5
      now += 24
    when now < 6
      day = (time - 1.day).strftime('%w')
      close = 30
      now = 24
    when now > 23
      day = time.strftime('%w')
      close = now + 1.5
    else
      day = time.strftime('%w')
      close = 25
    end

    { open: now, close: close, day: Timetable::WORKING_DAYS[day.to_i] }
  end

  def es_place_group_parametrize
    value.gsub(/network_/, '')
  end

  def es_center_parametrize
    true
  end

  def es_metro_parametrize
    {
      location: metro_station.location.to_a,
      distance: metro_station.search_radius
    }
  end

  def es_mode_parametrize
    if value.include?('restaurants')
      %i(restaurant cafe)
    elsif value.include?('bars')
      %i(bar club)
    end
  end

  def es_category_parametrize
    value
  end

  def es_birthday_discount_parametrize
    true
  end

  def es_with_likes_parametrize
    true
  end

  def es_latest_parametrize
    true
  end

  def es_popular_parametrize
    true
  end

  def es_working_day_parametrize
    day =
      case value
      when 'working_today'
        Date.today
      when "valentine's day"
        Date.parse('14.02.2015')
      when '8 march'
        Date.parse('08.03.2015')
      else
        Date.parse(value.split('_').last)
      end

    { day: day, timetable_day: Timetable::WORKING_DAYS[day.wday] }
  end

  def es_places(city_id = nil)
    Place.es_filter(
      kind.to_sym => [es_params],
      :city_id => city_id
    ).per(10_000).records
  end

  def to_label
    metro? ? metro_station.to_label : title
  end

  def iphone_title
    super || title
  end

  def mobile_title_formated
    mobile_title.gsub(/\r\n?/, "\n").gsub(/__/, "\u00A0") if mobile_title
  end

  def current_filter_features
    filter_features.includes(:feature).map do |ff|
      {
        id: ff.feature_id,
        kind: ff.feature.kind,
        min_weight: ff.min_weight
      }
    end
  end

  def mobile_icon_show
    mobile_icon.url(:show) if mobile_icon_file_name
  end

  def mobile_icon_show_2x
    mobile_icon.url(:show_2x) if mobile_icon_file_name
  end

  def mobile_icon_show_3x
    mobile_icon.url(:show_3x) if mobile_icon_file_name
  end

  class << self
    def features_by_values(values)
      Feature.joins(:filter_features)
        .where(
          filter_features: { search_filter_id: where(value: values).pluck(:id) }
        )
        .uniq
    end

    def es_serialize(opts)
      where(value: opts).inject({}) do |memo, filter|
        current_ff = filter.current_filter_features

        if current_ff.any?
          memo[:feature] ||= []
          memo[:feature] << current_ff
        end

        unless filter.kind.to_sym == :feature
          memo[filter.kind.to_sym] ||= []
          memo[filter.kind.to_sym] << filter.es_params
        end

        memo
      end
    end

    def es_places(city_id, *values)
      criteria = es_serialize(values)
      criteria[:position_sort] = true
      criteria[:city_id] = city_id if city_id

      Place.es_filter(criteria)
    end
  end
end
