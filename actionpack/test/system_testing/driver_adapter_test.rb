require 'abstract_unit'

class DriverAdapterTest < ActiveSupport::TestCase
  test 'only registered adapters are accepted' do
    assert_raises(NameError) do
      Rails::SystemTestCase.driver = :whatever
    end

    assert_nothing_raised do
      Rails::SystemTestCase.driver = :capybara_selenium_driver
    end
  end

  test 'settings can only be used for the appropriate adapter' do
    assert_raises(ArgumentError) do
      Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraRackTestDriver.new(something: 'test')
    end
  end
end
