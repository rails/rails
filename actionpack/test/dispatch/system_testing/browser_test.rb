require "abstract_unit"
require "action_dispatch/system_testing/browser"

class BrowserTest < ActiveSupport::TestCase
  test "initializing the browser" do
    browser = ActionDispatch::SystemTesting::Browser.new(:chrome, [ 1400, 1400 ])
    assert_equal :chrome, browser.instance_variable_get(:@name)
    assert_equal [ 1400, 1400 ], browser.instance_variable_get(:@screen_size)
  end
end
