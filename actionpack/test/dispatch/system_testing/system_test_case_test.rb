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

class SetHostTest < DrivenByRackTest
  test "sets default host" do
    assert_equal "http://127.0.0.1", Capybara.app_host
  end

  test "overrides host" do
    host! "http://example.com"

    assert_equal "http://example.com", Capybara.app_host
  end
end
