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

class RateLimitedSharedController < ActionController::Base
  self.cache_store = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 2, within: 2.seconds, context: "shared"
end

class RateLimitedSharedOneController < RateLimitedSharedController
  def limited_shared_one
    head :ok
  end
end

class RateLimitedSharedTwoController < RateLimitedSharedController
  def limited_shared_two
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  setup do
    RateLimitedController.cache_store.clear
    @controller = RateLimitedController.new
  end

  test "exceeding basic limit" do
    setup_routes do
      get :limited
      get :limited
      assert_response :ok

      get :limited
      assert_response :too_many_requests
    end
  end

  test "notification on limit action" do
    setup_routes do
      get :limited
      get :limited

      assert_notification("rate_limit.action_controller",
          count: 3,
          to: 2,
          within: 2.seconds,
          name: nil,
          by: request.remote_ip,
          context: @controller.controller_path) do
        get :limited
      end
    end
  end

  test "multiple rate limits" do
    setup_routes do
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
  end

  test "limit resets after time" do
    setup_routes do
      get :limited
      get :limited
      assert_response :ok

      travel_to Time.now + 3.seconds do
        get :limited
        assert_response :ok
      end
    end
  end

  test "limit by" do
    setup_routes do
      get :limited_with
      get :limited_with
      get :limited_with
      assert_response :forbidden

      get :limited_with, params: { rate_limit_key: "other" }
      assert_response :ok
    end
  end

  test "limited with" do
    setup_routes do
      get :limited_with
      get :limited_with
      get :limited_with
      assert_response :forbidden
    end
  end

  test "shared rate limit" do
    setup_routes do
      @controller = RateLimitedSharedOneController.new

      get :limited_shared_one
      get :limited_shared_one
      assert_response :ok

      @controller = RateLimitedSharedTwoController.new

      get :limited_shared_two
      assert_response :too_many_requests

      @controller = RateLimitedSharedOneController.new

      get :limited_shared_one
      assert_response :too_many_requests
    end
  end

  private
    def setup_routes
      with_routing do |routing|
        routing.draw do
          get :limited, to: "rate_limited#limited"
          get :limited_with, to: "rate_limited#limited_with"
          get :limited_shared_one, to: "rate_limited_shared_one#limited_shared_one"
          get :limited_shared_two, to: "rate_limited_shared_two#limited_shared_two"
        end

        yield if block_given?
      end
    end
end
