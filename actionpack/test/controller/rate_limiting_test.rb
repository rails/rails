# frozen_string_literal: true

require "abstract_unit"
require "kredis"

Kredis.configurator = Class.new do
  def config_for(name) { db: "2" } end
  def root() Pathname.new(Dir.pwd) end
end.new

# Enable Kredis logging
# ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT)

REDIS_TEST_SEGGREGATION = Random.hex(10)

class RateLimitedController < ActionController::Base
  rate_limit to: 2, within: 2.seconds, by: -> { "#{REDIS_TEST_SEGGREGATION}:static" }, only: :limited_to_two

  def limited_to_two
    head :ok
  end

  rate_limit to: 2, within: 2.seconds, by: -> { "#{REDIS_TEST_SEGGREGATION}:static" }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    head :ok
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    Kredis.counter("rate-limit:rate_limited:#{REDIS_TEST_SEGGREGATION}:static").del
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

    sleep 2.1
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
