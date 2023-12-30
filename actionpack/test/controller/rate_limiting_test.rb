# frozen_string_literal: true

require "abstract_unit"
require "kredis"

Kredis.configurator = Class.new do
  def config_for(name) { db: "2" } end
  def root() Pathname.new(Dir.pwd) end
end.new

# Enable Kredis logging
# ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT)

class RateLimitedController < ActionController::Base
  rate_limit to: 2, within: 2.seconds, by: -> { Thread.current[:redis_test_seggregation] }, only: :limited_to_two

  def limited_to_two
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: -> { Thread.current[:redis_test_seggregation] }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    Thread.current[:redis_test_seggregation] = Random.hex(10)
    Kredis.counter("rate-limit:rate_limited:#{Thread.current[:redis_test_seggregation]}").del
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

    sleep 3
    get :limited_to_two
    assert_response :ok
  end

  test "limited with" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end
end
