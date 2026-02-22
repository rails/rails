# frozen_string_literal: true

require "abstract_unit"

class CurrentTimeZoneController < ActionController::Base
  include ActionController::CurrentTimeZone
  set_current_time_zone_from -> { cookies[:time_zone] }

  def show
    render plain: Time.zone.name
  end
end

class CurrentTimeZoneCustomCookieController < ActionController::Base
  include ActionController::CurrentTimeZone
  set_current_time_zone_from -> { cookies[:user_time_zone] }

  def show
    render plain: Time.zone.name
  end
end

class CurrentTimeZoneTest < ActionController::TestCase
  tests CurrentTimeZoneController

  setup do
    @default_zone = Time.zone
    Time.zone = "UTC"
  end

  teardown do
    Time.zone = @default_zone
  end

  test "uses the time zone from the cookie when valid" do
    @request.cookies[:time_zone] = "America/New_York"
    get :show
    assert_equal "America/New_York", response.body
  end

  test "falls back to the default time zone when cookie is absent" do
    get :show
    assert_equal "UTC", response.body
  end

  test "falls back to the default time zone when cookie contains an unknown time zone" do
    @request.cookies[:time_zone] = "Not/ATimezone"
    get :show
    assert_equal "UTC", response.body
  end
end

class CurrentTimeZoneCustomCookieTest < ActionController::TestCase
  tests CurrentTimeZoneCustomCookieController

  setup do
    @default_zone = Time.zone
    Time.zone = "UTC"
  end

  teardown do
    Time.zone = @default_zone
  end

  test "reads time zone from the configured source" do
    @request.cookies[:user_time_zone] = "America/Chicago"
    get :show
    assert_equal "America/Chicago", response.body
  end

  test "ignores other sources when a custom callable is configured" do
    @request.cookies[:time_zone] = "America/New_York"
    get :show
    assert_equal "UTC", response.body
  end
end
