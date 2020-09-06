# frozen_string_literal: true

require 'abstract_unit'
require 'selenium/webdriver'

class SetDriverToRackTestTest < DrivenByRackTest
  test 'uses rack_test' do
    assert_equal :rack_test, Capybara.current_driver
  end
end

class OverrideSeleniumSubclassToRackTestTest < DrivenBySeleniumWithChrome
  driven_by :rack_test

  test 'uses rack_test' do
    assert_equal :rack_test, Capybara.current_driver
  end
end

class SetDriverToSeleniumTest < DrivenBySeleniumWithChrome
  test 'uses selenium' do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetDriverToSeleniumHeadlessChromeTest < DrivenBySeleniumWithHeadlessChrome
  test 'uses selenium headless chrome' do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetDriverToSeleniumHeadlessFirefoxTest < DrivenBySeleniumWithHeadlessFirefox
  test 'uses selenium headless firefox' do
    assert_equal :selenium, Capybara.current_driver
  end
end

class SetHostTest < DrivenByRackTest
  test 'overrides host' do
    assert_deprecated do
      host! 'http://example.com'
    end

    assert_equal 'http://example.com', Capybara.app_host
  end
end
