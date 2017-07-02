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

class UndefMethodsTest < DrivenBySeleniumWithChrome
  test "get" do
    assert_raise NoMethodError do
      get "http://example.com"
    end
  end

  test "post" do
    assert_raise NoMethodError do
      post "http://example.com"
    end
  end

  test "put" do
    assert_raise NoMethodError do
      put "http://example.com"
    end
  end

  test "patch" do
    assert_raise NoMethodError do
      patch "http://example.com"
    end
  end

  test "delete" do
    assert_raise NoMethodError do
      delete "http://example.com"
    end
  end
end
