class Pages::ErrorsController < ApplicationController
  layout false

  def not_found
    render "pages/errors/404", :status => 404
  end

  def rejected_change
    render "pages/errors/422", :status => 422
  end

  def error
    render "pages/errors/500", :status => 500
  end
end
