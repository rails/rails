# frozen_string_literal: true

require "abstract_unit"

class ControllerWithBeforeActionAndDefaultUrlOptions < ActionController::Base
  before_action { I18n.locale = params[:locale] }
  after_action { I18n.locale = "en" }

  def target
    render plain: "final response"
  end

  def redirect
    redirect_to action: "target"
  end

  def default_url_options
    { locale: "de" }
  end
end

class ControllerWithBeforeActionAndDefaultUrlOptionsTest < ActionController::TestCase
  # This test has its roots in issue #1872
  test "should redirect with correct locale :de" do
    get :redirect, params: { locale: "de" }
    assert_redirected_to "/controller_with_before_action_and_default_url_options/target?locale=de"
  end
end
