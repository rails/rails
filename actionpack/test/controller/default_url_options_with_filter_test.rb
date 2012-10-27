require 'abstract_unit'


class ControllerWithBeforeFilterAndDefaultUrlOptions < ActionController::Base

  before_filter { I18n.locale = params[:locale] }
  after_filter { I18n.locale = "en" }

  def target
    render :text => "final response"
  end

  def redirect
    redirect_to :action => "target"
  end

  def default_url_options
    {:locale => "de"}
  end
end

class ControllerWithBeforeFilterAndDefaultUrlOptionsTest < ActionController::TestCase

  # This test has its roots in issue #1872
  test "should redirect with correct locale :de" do
    get :redirect, :locale => "de"
    assert_redirected_to "/controller_with_before_filter_and_default_url_options/target?locale=de"
  end
end
