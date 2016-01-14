class Site::JoinUsController < ApplicationController
  def create
    if all_params?
      Notifier.delay.gettable_join_us_mail(params)
      render nothing: true, status: :created
    else
      render nothing: true, status: :bad_request
    end
  end

  private

  def all_params?
    %w(action contact email name phone rank).all? { |param| params[param].present? }
  end
end
