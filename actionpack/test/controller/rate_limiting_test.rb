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
end

class RateLimitedBaseController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
end

class RateLimitedSharedOneController < RateLimitedBaseController
  rate_limit to: 2, within: 2.seconds, scope: "shared"

  def limited_shared_one
    head :ok
  end
end

class RateLimitedSharedTwoController < RateLimitedBaseController
  rate_limit to: 2, within: 2.seconds, scope: "shared"

  def limited_shared_two
    head :ok
  end
end

class RateLimitedSharedController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds
end

class RateLimitedSharedThreeController < RateLimitedSharedController
  def limited_shared_three
    head :ok
  end
end

class RateLimitedSharedFourController < RateLimitedSharedController
  def limited_shared_four
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    RateLimitedController.cache_store.clear
  end

  test "exceeding basic limit" do
    get :limited
    get :limited
    assert_response :ok

    get :limited
    assert_response :too_many_requests
  end

  test "notification on limit action" do
    get :limited
    get :limited

    assert_notification("rate_limit.action_controller",
        count: 3,
        to: 2,
        within: 2.seconds,
        name: nil,
        by: request.remote_ip) do
      get :limited
    end
  end

  test "multiple rate limits" do
    get :limited
    get :limited
    assert_response :ok

    travel_to 3.seconds.from_now do
      get :limited
      get :limited
      assert_response :ok
    end

    travel_to 3.seconds.from_now do
      get :limited
      get :limited
      assert_response :too_many_requests
    end
  end

  test "limit resets after time" do
    get :limited
    get :limited
    assert_response :ok

    travel_to Time.now + 3.seconds do
      get :limited
      assert_response :ok
    end
  end

  test "limit by" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden

    get :limited_with, params: { rate_limit_key: "other" }
    assert_response :ok
  end

  test "limited with" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end

  test "exceeding limit writes to the request and response" do
    freeze_time

    5.times do
      get :limited
      travel 1.second

      assert_response :ok
      assert_nil request.rate_limit
      assert_nil response.retry_after
    end

    get :limited

    assert_response :too_many_requests
    assert_equal "long-term", request.rate_limit.name
    assert_equal RateLimitedController.controller_name, request.rate_limit.scope
    assert_equal 5, request.rate_limit.limit
    assert_equal 6, request.rate_limit.count
    assert_equal "rate-limit:rate_limited:long-term:#{request.remote_ip}", request.rate_limit.cache_key
    assert_equal request.remote_ip, request.rate_limit.by
    assert_equal 1.minute.from_now.httpdate, response.retry_after
    assert_equal 1.minute.from_now.httpdate, response.headers["Retry-After"]
  end

  test "cross-controller rate limit" do
    @controller = RateLimitedSharedOneController.new
    get :limited_shared_one
    assert_response :ok

    get :limited_shared_one
    assert_response :ok

    @controller = RateLimitedSharedTwoController.new

    get :limited_shared_two
    assert_response :too_many_requests

    @controller = RateLimitedSharedOneController.new

    get :limited_shared_one
    assert_response :too_many_requests
  ensure
    RateLimitedBaseController.cache_store.clear
  end

  test "inherited rate limit isn't shared between controllers" do
    @controller = RateLimitedSharedThreeController.new
    get :limited_shared_three
    assert_response :ok

    get :limited_shared_three
    assert_response :ok

    @controller = RateLimitedSharedFourController.new

    get :limited_shared_four
    assert_response :ok

    @controller = RateLimitedSharedThreeController.new

    get :limited_shared_three
    assert_response :too_many_requests
  ensure
    RateLimitedSharedController.cache_store.clear
  end
end
