require 'test_helper'

class <%= camelized %>Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, <%= camelized %>
  end
end
