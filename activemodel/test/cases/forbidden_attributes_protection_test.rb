require 'cases/helper'
require 'active_support/core_ext/hash/indifferent_access'
require 'models/account'

class ProtectedParams < ActiveSupport::HashWithIndifferentAccess
  attr_accessor :permitted
  alias :permitted? :permitted

  def initialize(attributes)
    super(attributes)
    @permitted = false
  end

  def permit!
    @permitted = true
    self
  end
end

class ActiveModelMassUpdateProtectionTest < ActiveSupport::TestCase
  test "forbidden attributes cannot be used for mass updating" do
    params = ProtectedParams.new({ "a" => "b" })
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Account.new.sanitize_for_mass_assignment(params)
    end
  end

  test "permitted attributes can be used for mass updating" do
    params = ProtectedParams.new({ "a" => "b" }).permit!
    assert_equal({ "a" => "b" }, Account.new.sanitize_for_mass_assignment(params))
  end

  test "regular attributes should still be allowed" do
     assert_equal({ a: "b" }, Account.new.sanitize_for_mass_assignment(a: "b"))
  end
end
