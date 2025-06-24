# frozen_string_literal: true

require "abstract_unit"

class ApiRateLimitedController < ActionController::API
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds, only: :limited_to_two

  def limited_to_two
    head :ok
  end
end

class ApiRateLimitingTest < ActionController::TestCase
  tests ApiRateLimitedController

  setup do
    ApiRateLimitedController.cache_store.clear
  end

  test "exceeding basic limit" do
    get :limited_to_two
    get :limited_to_two
    assert_response :ok

    get :limited_to_two
    assert_response :too_many_requests
  end

  test "limit resets after time" do
    get :limited_to_two
    get :limited_to_two
    assert_response :ok

    travel_to Time.now + 3.seconds do
      get :limited_to_two
      assert_response :ok
    end
  end
end
