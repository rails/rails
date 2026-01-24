# frozen_string_literal: true

require "abstract_unit"

class AllowBrowserController < ActionController::Base
  allow_browser versions: { safari: "16.4", chrome: "119", firefox: "123", opera: "106", ie: false }, block: -> { head :upgrade_required }, only: :hello
  def hello
    head :ok
  end

  allow_browser versions: { safari: "16.4", chrome: "119", firefox: "123", opera: "106", ie: false }, block: :head_upgrade_required, only: :hello_method_name
  def hello_method_name
    head :ok
  end

  allow_browser versions: :modern, block: -> { head :upgrade_required }, only: :modern
  def modern
    head :ok
  end

  private
    def head_upgrade_required
      head :upgrade_required
    end
end

class AllowBrowserTest < ActionController::TestCase
  tests AllowBrowserController

  CHROME_118    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118 Safari/537.36"
  CHROME_120    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
  SAFARI_17_2_0 = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.0 Safari/605.1.15"
  FIREFOX_114   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/114.0"
  IE_11         = "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko"
  OPERA_106     = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 OPR/106.0.0.0"
  GOOGLE_BOT    = "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/W.X.Y.Z Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  test "blocked browser below version limit with callable" do
    get_with_agent :hello, FIREFOX_114
    assert_response :upgrade_required
  end

  test "blocked browser below version limit with method name" do
    get_with_agent :hello_method_name, FIREFOX_114
    assert_response :upgrade_required
  end

  test "blocked browser by name" do
    get_with_agent :hello, IE_11
    assert_response :upgrade_required
  end

  test "allowed browsers above specific version limit" do
    get_with_agent :hello, SAFARI_17_2_0
    assert_response :ok

    get_with_agent :hello, CHROME_120
    assert_response :ok

    get_with_agent :hello, OPERA_106
    assert_response :ok
  end

  test "browsers against modern limit" do
    get_with_agent :modern, SAFARI_17_2_0
    assert_response :ok

    get_with_agent :modern, CHROME_118
    assert_response :upgrade_required

    get_with_agent :modern, CHROME_120
    assert_response :ok

    get_with_agent :modern, OPERA_106
    assert_response :ok
  end

  test "bots" do
    get_with_agent :hello, GOOGLE_BOT
    assert_response :ok

    get_with_agent :modern, GOOGLE_BOT
    assert_response :ok
  end

  test "a blocked request instruments a browser_block.action_controller event" do
    notification = assert_notification("browser_block.action_controller") do
      get_with_agent :modern, CHROME_118
    end

    assert_equal request, notification.payload[:request]
    assert_not_empty notification.payload[:versions]
  end

  private
    def get_with_agent(action, agent)
      @request.headers["User-Agent"] = agent
      get action
    end
end
