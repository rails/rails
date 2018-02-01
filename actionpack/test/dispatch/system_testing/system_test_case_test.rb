# frozen_string_literal: true

require "abstract_unit"

class SetDriverToRackTestTest < DrivenByRackTest
  test "uses rack_test" do
    assert_equal :rack_test, Capybara.current_driver
  end
end

class OverrideSeleniumSubclassToRackTestTest < DrivenBySeleniumWithChrome
  driven_by :rack_test

  test "uses rack_test" do
    assert_equal :rack_test, Capybara.current_driver
  end
end

class SetDriverToSeleniumTest < DrivenBySeleniumWithChrome
  test "uses selenium" do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetDriverToSeleniumHeadlessChromeTest < DrivenBySeleniumWithHeadlessChrome
  test "uses selenium headless chrome" do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetDriverToSeleniumHeadlessFirefoxTest < DrivenBySeleniumWithHeadlessFirefox
  test "uses selenium headless firefox" do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetHostTest < DrivenByRackTest
  test "sets default host" do
    assert_equal "http://127.0.0.1", Capybara.app_host
  end

  test "overrides host" do
    host! "http://example.com"

    assert_equal "http://example.com", Capybara.app_host
  end
end

class UndefMethodsTest < DrivenBySeleniumWithChrome
  test "get" do
    exception = assert_raise NoMethodError do
      get "http://example.com"
    end
    assert_equal "System tests cannot make direct requests via #get; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information.", exception.message
  end

  test "post" do
    exception = assert_raise NoMethodError do
      post "http://example.com"
    end
    assert_equal "System tests cannot make direct requests via #post; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information.", exception.message
  end

  test "put" do
    exception = assert_raise NoMethodError do
      put "http://example.com"
    end
    assert_equal "System tests cannot make direct requests via #put; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information.", exception.message
  end

  test "patch" do
    exception = assert_raise NoMethodError do
      patch "http://example.com"
    end
    assert_equal "System tests cannot make direct requests via #patch; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information.", exception.message
  end

  test "delete" do
    exception = assert_raise NoMethodError do
      delete "http://example.com"
    end
    assert_equal "System tests cannot make direct requests via #delete; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information.", exception.message
  end
end
