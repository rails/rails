require "abstract_unit"

class SystemTestCaseTest < ActiveSupport::TestCase
  test "driven_by sets Capybara's default driver to poltergeist" do
    ActionDispatch::SystemTestCase.driven_by :poltergeist

    assert_equal :poltergeist, Capybara.default_driver
  end

  test "driven_by sets Capybara's drivers respectively" do
    ActionDispatch::SystemTestCase.driven_by :selenium, using: :chrome

    assert_includes Capybara.drivers, :selenium
    assert_includes Capybara.drivers, :chrome
    assert_equal :chrome, Capybara.default_driver
  end

  test "selenium? returns false if driver is poltergeist" do
    assert_not ActionDispatch::SystemTestCase.selenium?(:poltergeist)
  end
end
