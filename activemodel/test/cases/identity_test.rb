require "cases/helper"

class IdentityTest < ActiveModel::TestCase
  class IdentityModel
    include ActiveModel::Identity
    attr_accessor :id, :attr

    def initialize(options = {})
      options.each { |name, value| send("#{name}=", value) }
    end
  end

  class IdentityKeysModel < IdentityModel
    def key_attributes
      [:attr]
    end
  end

  test "to_key default implementation returns nil for new records" do
    assert_nil IdentityModel.new.to_key
  end

  test "to_key default implementation returns the id in an array for persisted records" do
    assert_equal ['foo'], IdentityKeysModel.new(attr: 'foo').to_key
  end

  # Note: This is a performance optimization for Array#uniq and Hash#[] with
  # AR::Base objects. If the future has made this irrelevant, feel free to
  # delete this.
  test "records without key attributes set have unique hashes" do
    assert_not_equal IdentityKeysModel.new.hash, IdentityKeysModel.new.hash
  end

  test "objects with the same key attribute values are considered equal" do
    assert_equal IdentityKeysModel.new(attr: 1), IdentityKeysModel.new(attr: 1)
  end

  test "objects with blank key attributes are considered equal" do
    one = IdentityKeysModel.new(attr: '')
    two = IdentityKeysModel.new(attr: '')
    assert_equal one, two
  end

  test "hashes the elements by key attributes" do
    assert_equal [ IdentityKeysModel.new(attr: 1) ], [ IdentityKeysModel.new(attr: 1) ] & [ IdentityKeysModel.new(attr: 1) ]
  end
end
