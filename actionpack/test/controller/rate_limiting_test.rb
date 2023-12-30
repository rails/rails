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
  rate_limit to: 2, within: 3.seconds, by: -> { "#{REDIS_TEST_SEGGREGATION}:#{request.remote_ip}" }, only: :limited_to_two

  def limited_to_two
    render plain: "Made it!"
  end

  rate_limit to: 2, within: 5.seconds, by: -> { "#{REDIS_TEST_SEGGREGATION}:static" }, only: :limited_by_static

  def limited_by_static
    render plain: "Made it!"
  end

  rate_limit to: 2, within: 3.seconds, by: -> { "#{REDIS_TEST_SEGGREGATION}:#{request.remote_ip}" }, with: -> { head :forbidden }, only: :limited_with
  def limited_with
    render plain: "Made it!"
  end
end

class RateLimitingTest < ActionController::TestCase
  tests RateLimitedController

  setup do
    Kredis.counter("rate-limit:rate_limited:#{REDIS_TEST_SEGGREGATION}:0.0.0.0").del
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

    sleep 3.1
    get :limited_to_two
    assert_response :ok
  end

  test "limited by static" do
    get :limited_by_static
    get :limited_by_static
    assert_response :ok
    assert_equal 2, Kredis.counter("rate-limit:rate_limited:#{REDIS_TEST_SEGGREGATION}:static").value
  ensure
    Kredis.counter("rate-limit:rate_limited:#{REDIS_TEST_SEGGREGATION}:static").del
  end

  test "limited with" do
    get :limited_with
    get :limited_with
    get :limited_with
    assert_response :forbidden
  end
end
