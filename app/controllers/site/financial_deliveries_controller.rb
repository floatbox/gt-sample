class Site::FinancialDeliveriesController < Site::BaseController

  def confirm
    fm = FinancialMonth.find_by delivery_uid: params[:delivery_uid]
    if fm && fm.state == 'report_sended' && fm.sign == params[:sign]
      FinancialNotifier.delay.report_confirm(fm)
    end

    render :text => 'Спасибо за подтверждение!', :layout => false
  end

end
