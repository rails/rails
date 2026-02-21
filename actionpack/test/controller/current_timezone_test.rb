# frozen_string_literal: true

require "abstract_unit"

class CurrentTimezoneController < ActionController::Base
  include ActionController::CurrentTimezone

  def show
    render plain: Time.zone.name
  end

  def cacheable
    if stale?(etag: "static")
      head :ok
    end
  end
end

class CurrentTimezoneCustomCookieController < ActionController::Base
  include ActionController::CurrentTimezone
  self.timezone_cookie_name = :user_timezone

  def show
    render plain: Time.zone.name
  end
end

class CurrentTimezoneTest < ActionController::TestCase
  tests CurrentTimezoneController

  setup do
    @default_zone = Time.zone
    Time.zone = "UTC"
  end

  teardown do
    Time.zone = @default_zone
  end

  test "uses the timezone from the cookie when valid" do
    @request.cookies[:timezone] = "America/New_York"
    get :show
    assert_equal "America/New_York", response.body
  end

  test "falls back to the default timezone when cookie is absent" do
    get :show
    assert_equal "UTC", response.body
  end

  test "falls back to the default timezone when cookie contains an unknown timezone" do
    @request.cookies[:timezone] = "Not/ATimezone"
    get :show
    assert_equal "UTC", response.body
  end

  test "timezone_from_cookie is exposed as a helper method" do
    assert_includes CurrentTimezoneController._helper_methods, :timezone_from_cookie
  end

  test "timezone cookie is included in ETag computation" do
    ny = ActiveSupport::TimeZone["America/New_York"]
    expected = "W/\"#{ActiveSupport::Digest.hexdigest(ActiveSupport::Cache.expand_cache_key(["static", ny]))}\""

    @request.cookies[:timezone] = "America/New_York"
    get :cacheable

    assert_equal expected, response.headers["ETag"]
  end

  test "ETag excludes timezone when cookie is absent" do
    expected = "W/\"#{ActiveSupport::Digest.hexdigest(ActiveSupport::Cache.expand_cache_key(["static"]))}\""

    get :cacheable

    assert_equal expected, response.headers["ETag"]
  end
end

class CurrentTimezoneCustomCookieTest < ActionController::TestCase
  tests CurrentTimezoneCustomCookieController

  setup do
    @default_zone = Time.zone
    Time.zone = "UTC"
  end

  teardown do
    Time.zone = @default_zone
  end

  test "reads timezone from the configured cookie name" do
    @request.cookies[:user_timezone] = "America/Chicago"
    get :show
    assert_equal "America/Chicago", response.body
  end

  test "ignores the default cookie name when a custom name is configured" do
    @request.cookies[:timezone] = "America/New_York"
    get :show
    assert_equal "UTC", response.body
  end
end
