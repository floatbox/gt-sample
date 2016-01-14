class GiftItem < ActiveRecord::Base
  include GiftItemPresenter

  belongs_to :gift
  belongs_to :user

  has_attached_file :pdf_file, { path: "gift_items/:id/gift.pdf" }.merge(PAPERCLIP_STORAGE_OPTIONS)
  validates_attachment_content_type :pdf_file, content_type: ['application/pdf'], allow_blank: true

  validate :check_delivery_item

  scope :free, -> { where(presented_at: nil)  }
  scope :given, -> { where.not(presented_at: nil) }
  scope :sorted, -> { order(:step_level) }
  scope :active, -> { free.where(hold: false) }
  scope :holden, -> { free.where(hold: true) }
  scope :for_places, -> { joins(:gift).where(gifts:{kind:'place'}) }
  scope :activated, -> { where.not(used_at: nil) }

  delegate :title, :emoji, :kind, :info, :text, :delivery_type, :address, :url,
    :info_url, :app_url, :phone, :howtoget, :place, :place_id, to: :gift, allow_nil: true

  def pdf_file_url
    pdf_file.url if pdf_file_file_name
  end

  def expired_in(date)
    expiry_at.present? && expiry_at < date.to_time
  end

  def place_deeplink
    "gettable://places/#{place_id}/booking?comment=#{code}"
  end

  def give_to_user(user)
    update(
      user: user,
      step_level: user.next_gift_steps,
      presented_at: Time.zone.now
    )
  end

  private

  def check_delivery_item
    if gift
      check_delivery_fee

      case delivery_type
      when 'code'
        errors.add(:code, 'Не должен быть пустым') if code.blank?
      when 'pdf'
        errors.add(:pdf_file, 'Не должен быть пустым') if pdf_file.blank?
      end
    end
  end

  def check_delivery_fee
    errors.add(:base, 'Должен присутствовать либо "code" либо "pdf_file"') if code.blank? && pdf_file.blank?
  end

end
