require 'abstract_unit'


class DefaultUrlOptionsController < ActionController::Base

  before_filter { I18n.locale = params[:locale] }

  def redirect_target
    render :text => "index1"
  end

  def redirect
    redirect_to :action => "redirect_target"
  end

  def default_url_options(options={})
    {:locale => I18n.locale}.merge(options)
  end

end

class DefaultUrlOptionsControllerTest < ActionController::TestCase

  def setup
    @controller = DefaultUrlOptionsController.new
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/default_url_options/redirect_target" => "default_url_options#redirect_target"
      get "/default_url_options/redirect" => "default_url_options#redirect"
    end
  end

  # This test has it´s roots in issue #1872 
  test "should redirect with correct locale :de" do
    get :redirect, :locale => "de"
    assert_redirected_to "/default_url_options/redirect_target?locale=de"
  end
end


