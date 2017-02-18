require "active_support/testing/autorun"
require "action_system_test"

class ActionSystemTestTest < ActiveSupport::TestCase
  test "driven_by sets Capybara's default driver to poltergeist" do
    ActionSystemTest::Base.driven_by :poltergeist

    assert_equal :poltergeist, Capybara.default_driver
  end

  test "driven_by sets Capybara's drivers respectively" do
    ActionSystemTest::Base.driven_by :selenium, using: :chrome

    assert_includes Capybara.drivers, :selenium
    assert_includes Capybara.drivers, :chrome
    assert_equal :chrome, Capybara.default_driver
  end

  test "selenium? returns false if driver is poltergeist" do
    assert_not ActionSystemTest::Base.selenium?(:poltergeist)
  end
end
