# frozen_string_literal: true

require "abstract_unit"

class ImplicitRenderAPITestController < ActionController::API
  def empty_action
  end

  def returning_mock
    require "minitest/mock"
    Minitest::Mock.new
  end
end

class ImplicitRenderAPITest < ActionController::TestCase
  tests ImplicitRenderAPITestController

  def test_implicit_no_content_response
    get :empty_action
    assert_response :no_content
  end

  def test_result_independence
    get :returning_mock
    assert_response :no_content
  end
end
