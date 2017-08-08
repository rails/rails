# frozen_string_literal: true

require "abstract_unit"

class ImplicitRenderAPITestController < ActionController::API
  def empty_action
  end
end

class ImplicitRenderAPITest < ActionController::TestCase
  tests ImplicitRenderAPITestController

  def test_implicit_no_content_response
    get :empty_action
    assert_response :no_content
  end
end
