class Site::AdvUsController < ApplicationController
  def create
    if all_params?
      Notifier.delay.gettable_adv_us_mail(params)
      render nothing: true, status: :created
    else
      render nothing: true, status: :bad_request
    end
  end

  private

  def all_params?
    %w(action budget contact email name phone placements rank).all? { |param| params[param].present? }
  end
end
