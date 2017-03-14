require "abstract_unit"

class SetDriverToRackTestTest < DrivenByRackTest
  test "uses rack_test" do
    assert_equal :rack_test, Capybara.current_driver
  end
end

class SetDriverToSeleniumTest < DrivenBySeleniumWithChrome
  test "uses selenium" do
    assert_equal :selenium, Capybara.current_driver
  end
end
