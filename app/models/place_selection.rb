class PlaceSelection < ActiveRecord::Base
  include PhoneNormalizer, ActionView::Helpers::NumberHelper

  belongs_to :operator, :class_name => 'User', :foreign_key => 'operator_id'

  has_one    :booking

  has_many   :place_selection_places, :inverse_of => :place_selection
  has_many   :places, :through => :place_selection_places

  delegate :first_name, :to => :operator, :prefix => true

  accepts_nested_attributes_for :place_selection_places

  validates_presence_of :email, :phone, :name, :source, :date, :operator_id
  validates_numericality_of :budget, :greater_than => 0, :allow_blank => true
  validate :valid_email

  before_validation_on_create :set_defaults
  after_create :send_email

  def budget_explained
    if price_type == 'per_person'
      "#{number_to_currency(budget, :precision => 0)}/чел."
    elsif price_type == 'per_total'
      number_to_currency(budget, :precision => 0)
    end
  end

protected

  def valid_email
    email.split(/[,;]\s*/).each do |e|
      unless e =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
        errors.add(:email, "неправильный адрес эл. почты #{e}")
      end
    end if email
  end

  def set_defaults
    normalize_phone!
    self.source = 'gettable-phone' unless source
  end

  def send_email
    Notifier.delay.place_selection_email(email, self)
    Notifier.delay.place_selection_email(operator.email, self)
  end

end
