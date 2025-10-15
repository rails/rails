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

    assert_raises ActionController::TooManyRequests do
      get :limited
    end
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
      assert_raises ActionController::TooManyRequests do
        get :limited
      end
    end
  end

  test "multiple rate limits" do
    freeze_time
    get :limited
    get :limited
    assert_response :ok

    travel 3.seconds
    get :limited
    get :limited
    assert_response :ok

    travel 3.seconds
    get :limited
    assert_raises ActionController::TooManyRequests do
      get :limited
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

  test "cross-controller rate limit" do
    @controller = RateLimitedSharedOneController.new
    get :limited_shared_one
    assert_response :ok

    get :limited_shared_one
    assert_response :ok

    @controller = RateLimitedSharedTwoController.new

    assert_raises ActionController::TooManyRequests do
      get :limited_shared_two
    end

    @controller = RateLimitedSharedOneController.new

    assert_raises ActionController::TooManyRequests do
      get :limited_shared_one
    end
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

    assert_raises ActionController::TooManyRequests do
      get :limited_shared_three
    end
  ensure
    RateLimitedSharedController.cache_store.clear
  end
end
