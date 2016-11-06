require "abstract_unit"

class DriverAdapterTest < ActiveSupport::TestCase
  test "only registered adapters are accepted" do
    assert_raises(NameError) do
      ActionSystemTest.driver = :whatever
    end

    assert_nothing_raised do
      ActionSystemTest.driver = :rack_test
    end
  end
end
