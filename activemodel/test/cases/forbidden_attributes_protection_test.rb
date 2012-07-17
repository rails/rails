require 'cases/helper'
require 'models/account'

class ActiveModelMassUpdateProtectionTest < ActiveSupport::TestCase
  test "forbidden attributes cannot be used for mass updating" do
    params = { "a" => "b" }
    class << params
      define_method(:permitted?) { false }
    end
    assert_raises(ActiveModel::ForbiddenAttributes) do
      Account.new.sanitize_for_mass_assignment(params)
    end
  end

  test "permitted attributes can be used for mass updating" do
    params = { "a" => "b" }
    class << params
      define_method(:permitted?) { true }
    end
    assert_nothing_raised do
      assert_equal({ "a" => "b" },
        Account.new.sanitize_for_mass_assignment(params))
    end
  end

  test "regular attributes should still be allowed" do
    assert_nothing_raised do
      assert_equal({ a: "b" },
        Account.new.sanitize_for_mass_assignment(a: "b"))
    end
  end
end
