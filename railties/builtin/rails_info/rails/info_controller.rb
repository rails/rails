class Rails::InfoController < ActionController::Base
  def properties
    if consider_all_requests_local || local_request?
      render :inline => Rails::Info.to_html
    else
      render :text => '<p>For security purposes, this information is only available to local requests.</p>', :status => 500
    end
  end
end
