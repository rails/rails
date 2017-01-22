require "active_support/testing/autorun"
require "action_system_test"

class BrowserTest < ActiveSupport::TestCase
  test "initializing the browser" do
    browser = ActionSystemTest::Browser.new(:chrome, [ 1400, 1400 ])
    assert_equal :chrome, browser.instance_variable_get(:@name)
    assert_equal [ 1400, 1400 ], browser.instance_variable_get(:@screen_size)
  end
end
