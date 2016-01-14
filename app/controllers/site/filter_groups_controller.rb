class Site::FilterGroupsController < Site::BaseController

  def index
    prepare_filter_groups
  end

  def show
    @filter_group = FilterGroup.find_by value: params[:id]
  end

  private

  def prepare_filter_groups
    @filter_groups = case params[:kind]
    when 'site_index'
      site_index_filter
    else
      FilterGroup.where(kind: params[:kind])
    end
  end

  def site_index_filter
    FilterGroup.where(kind: params[:kind]).inject([]) do |memo, filter_group|
      case filter_group.value
      when 'discount_10perc'
        memo.unshift(filter_group) if current_city.msk?
      when 'resto_present_aug_2015'
        memo << filter_group if current_city.msk?
      else
        memo << filter_group
      end

      memo
    end
  end
end
