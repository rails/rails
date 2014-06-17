require "cases/helper"

class IdentityTest < ActiveModel::TestCase
  class IdentityModel
    include ActiveModel::Identity
    attr_accessor :id, :attr

    def initialize(options = {})
      options.each { |name, value| send("#{name}=", value) }
    end
  end

  # Note: This is a performance optimization for Array#uniq and Hash#[] with
  # AR::Base objects. If the future has made this irrelevant, feel free to
  # delete this.
  test "records without an id have unique hashes" do
    assert_not_equal IdentityModel.new.hash, IdentityModel.new.hash
  end

  test "objects with the same ID are considered equal" do
    assert_equal IdentityModel.new(id: 1), IdentityModel.new(id: 1)
  end

  test "objects with blank IDs are considered equal" do
    one = IdentityModel.new(id: '')
    two = IdentityModel.new(id: '')
    assert_equal one, two
  end

  test "hashes the elements by ID" do
    assert_equal [ IdentityModel.new(id: 1) ], [ IdentityModel.new(id: 1) ] & [ IdentityModel.new(id: 1) ]
  end
end
