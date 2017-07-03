require "abstract_unit"

class PathParameterEncodingController < ActionController::Base
  def show
    render body: "日本語： #{params[:id]}".encoding
  end
end

class PathParameterEncodingTest < ActionDispatch::IntegrationTest
  Routes = ::ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      get "/path_parameter_encoding/:id", to: "path_parameter_encoding#show"
    end
  end

  APP = build_app(Routes)

  def app
    APP
  end

  def test_properly_transcodes_path_parameters_which_contains_multibyte_characters
    get "/path_parameter_encoding/%E6%97%A5%E6%9C%AC%E8%AA%9E"
    assert_response :success
    assert_equal "UTF-8", @response.body
  end
end
