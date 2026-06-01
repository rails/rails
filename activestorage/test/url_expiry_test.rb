# frozen_string_literal: true

require "test_helper"

class ActiveStorage::UrlExpiryTest < ActiveSupport::TestCase
  setup do
    @old_service_urls_expire_in = ActiveStorage.service_urls_expire_in
    @old_urls_expire_in = ActiveStorage.urls_expire_in
  end

  teardown do
    ActiveStorage.service_urls_expire_in = @old_service_urls_expire_in
    ActiveStorage.urls_expire_in = @old_urls_expire_in
  end

  test "service_urls_expire_in returns a non-callable value as-is" do
    ActiveStorage.service_urls_expire_in = 10.minutes
    assert_equal 10.minutes, ActiveStorage.service_urls_expire_in
  end

  test "service_urls_expire_in invokes a callable on each read" do
    durations = [10.minutes, 20.minutes]
    ActiveStorage.service_urls_expire_in = -> { durations.shift }

    assert_equal 10.minutes, ActiveStorage.service_urls_expire_in
    assert_equal 20.minutes, ActiveStorage.service_urls_expire_in
  end

  test "urls_expire_in defaults to nil and returns a non-callable value as-is" do
    ActiveStorage.urls_expire_in = nil
    assert_nil ActiveStorage.urls_expire_in

    ActiveStorage.urls_expire_in = 1.day
    assert_equal 1.day, ActiveStorage.urls_expire_in
  end

  test "urls_expire_in invokes a callable on each read" do
    durations = [1.day, 2.days]
    ActiveStorage.urls_expire_in = -> { durations.shift }

    assert_equal 1.day, ActiveStorage.urls_expire_in
    assert_equal 2.days, ActiveStorage.urls_expire_in
  end
end
