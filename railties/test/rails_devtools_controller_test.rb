# frozen_string_literal: true

require "abstract_unit"

class DevtoolsControllerTest < ActionController::TestCase
  tests Rails::DevtoolsController

  def setup
    Rails.application.routes.draw do
      get ".well-known/appspecific/com.chrome.devtools.json" => "rails/devtools#show", internal: true
    end
    @routes = Rails.application.routes
  end

  test "devtools controller renders JSON with workspace root and uuid" do
    get :show
    assert_response :success
    assert_match(/application\/json/, @response.content_type)

    json_response = JSON.parse(@response.body)
    assert json_response.key?("workspace")
    assert json_response["workspace"].key?("root")
    assert json_response["workspace"].key?("uuid")
    assert_equal Rails.root.to_s, json_response["workspace"]["root"]
  end
end
