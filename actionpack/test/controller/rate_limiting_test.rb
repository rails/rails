# frozen_string_literal: true

require "abstract_unit"

class RateLimitedController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds, only: :limited_to_two

  def limited_to_two
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: -> { params[:rate_limit_key] }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    Thread.current[:redis_test_seggregation] = Random.hex(10)
    RateLimitedController.cache_store.clear
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

  test "limit by" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden

    get :limited_with, params: { rate_limit_key: "other" }
    get :limited_with
  end

  test "limited with" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end
end
