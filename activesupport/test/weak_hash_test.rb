require 'abstract_unit'
require 'active_support/weak_hash'

class WeakHashTest < ActiveSupport::TestCase

  def setup
    @weak_hash = ActiveSupport::WeakHash.new
    @str = "A";
    @obj = Object.new
  end

  test "allows us to assign value, and return assigned value" do
    a = @str; b = @obj
    assert_equal @weak_hash[a] = b, b
  end

  test "should allow us to assign and read value" do
    a = @str; b = @obj
    assert_equal @weak_hash[a] = b, b
    assert_equal @weak_hash[a], b
  end

  test "should use object_id to identify objects" do
    a = Object.new
    @weak_hash[a] = "b"
    assert_nil @weak_hash[a.dup]
  end

  test "should find objects that have same hash" do
    @weak_hash["a"] = "b"
    assert_equal "b", @weak_hash["a"]
  end
end
