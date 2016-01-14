class Site::ModesSliderController < Site::BaseController

  def kitchens
    @kitchens = [
      { href: method_name('/cuisine/italian'), image: 'site/kitchen1.png',title: 'Итальянская кухня' },
      { href: method_name("/cuisine/russian"), image: 'site/kitchen2.png', title: 'Русская кухня' },
      { href: method_name("/cuisine/japanese"), image: 'site/kitchen3.png', title: 'Японская кухня' },
      { href: method_name("/cuisine/georgian"), image: 'site/kitchen4.png', title: 'Грузинская кухня' },
      { href: method_name("/cuisine/chinese"), image: 'site/kitchen5.png', title: 'Китайская кухня' },
    ]

    @features = [
      { href: method_name("/feature/terrace"),   image: 'site/place-new-year.png', title: "С верандой" },
      { href: method_name("/feature/best"),      image: 'site/place-favorite.png', title: "Популярные" },
      { href: method_name("/bars"),              image: 'site/place-club.png',     title: "Бары и клубы" },
      { href: method_name("/feature/good_view"), image: 'site/place-interest.png', title: "С видом" },
      { href: method_name("/bars/beer"),         image: 'site/place-pub.png',      title: "Пивные" }
    ]
  end

  def main_slides
    @slides = [
      { title: 'Лучшие столики', description: 'Бронируйте лучшие столики бесплатно, получайте ', image: 'site/img-table.png', background: 'site/slider-bg-3.jpg' },
      { title: 'Лучший выбор', description: '__needle__ на одном сайте', image: 'site/img-map.png', background: 'site/slider-bg-1.jpg' },
      { title: 'Мобильное приложение', description: 'Все рестораны в кармане - скачайте бесплатное приложение', image: 'site/img-phone.png', background: 'site/slider-bg-2.jpg' }
    ]

    if current_city.msk? && Date.today < Date.parse('31.08.2015')
      discount = SiteLanding.find_by_permalink('/feature/discount_10').full_link
      @slides.first[:link_href] = discount
      @slides.first[:link_title] = 'приятные бонусы'
      @slides.first[:description] = 'Бронируйте лучшие столики бесплатно, получайте '
    else
      @slides.first[:description] = 'Бронируйте лучшие столики бесплатно, получайте приятные бонусы'
    end
  end

  private

  def method_name(path)
    part = current_city.msk? ? '/msk' : ''
    "#{part}#{path}"
  end

end
