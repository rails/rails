# frozen_string_literal: true

require "abstract_unit"

class RateLimitedController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds, only: :limited
  rate_limit to: 5, within: 1.minute, name: "long-term", only: :limited

  def limited
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: -> { params[:rate_limit_key] }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: :by_method, with: :head_forbidden, only: :limited_with_methods
  def limited_with_methods
    head :ok
  end

  private
    def by_method
      params[:rate_limit_key]
    end

    def head_forbidden
      head :forbidden
    end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    RateLimitedController.cache_store.clear
    freeze_time
  end

  test "exceeding basic limit" do
    get :limited
    get :limited
    assert_response :ok
    assert_nil request.rate_limit
    assert_nil response.retry_after

    assert_raises ActionController::TooManyRequests do
      get :limited
    end
  end

  test "multiple rate limits" do
    get :limited
    get :limited
    assert_response :ok

    travel 3.seconds
    get :limited
    get :limited
    assert_response :ok

    travel 3.seconds
    get :limited
    assert_response :ok

    assert_raises ActionController::TooManyRequests do
      get :limited
    end
  end

  test "limit resets after time" do
    get :limited
    get :limited
    assert_response :ok

    travel 3.seconds
    get :limited
    assert_response :ok
  end

  test "limit by callable" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden

    get :limited_with, params: { rate_limit_key: "other" }
    assert_response :ok
  end

  test "limited with callable" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end

  test "limit by method" do
    get :limited_with_methods
    get :limited_with_methods
    get :limited_with_methods
    assert_response :forbidden

    get :limited_with_methods, params: { rate_limit_key: "other" }
    assert_response :ok
  end

  test "limited with method" do
    get :limited_with_methods
    get :limited_with_methods
    get :limited_with_methods
    assert_response :forbidden
  end

  test "exceeding limit writes to the request and response" do
    get :limited
    get :limited

    assert_nil request.rate_limit
    assert_nil response.retry_after

    assert_raises ActionController::TooManyRequests do
      get :limited
    end
    assert_equal 2, request.rate_limit.count
    assert_equal 2.seconds.from_now, request.rate_limit.retry_after
    assert_equal 2.seconds.from_now.httpdate, response.retry_after
    assert_equal 2.seconds.from_now.httpdate, response.headers["Retry-After"]
  end

  test "exceeding limit publishes a rate_limit.action_controller event" do
    get :limited_with
    get :limited_with

    events = capture_instrumentation_events "rate_limit.action_controller" do
      get :limited_with
    end

    assert_includes(events.map(&:payload), { request: request })
  end

  private
    def capture_instrumentation_events(pattern, &block)
      events = []
      ActiveSupport::Notifications.subscribed(->(e) { events << e }, pattern, &block)
      events
    end
end
