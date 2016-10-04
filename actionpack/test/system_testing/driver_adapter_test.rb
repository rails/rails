require "abstract_unit"

class DriverAdapterTest < ActiveSupport::TestCase
  test "only registered adapters are accepted" do
    assert_raises(NameError) do
      Rails::SystemTestCase.driver = :whatever
    end

    assert_nothing_raised do
      Rails::SystemTestCase.driver = :rack_test
    end
  end
end
