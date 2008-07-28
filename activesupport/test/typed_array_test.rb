require 'abstract_unit'

class TypedArrayTest < Test::Unit::TestCase
  class StringArray < ActiveSupport::TypedArray
    def self.type_cast(obj)
      obj.to_s
    end
  end

  def setup
    @array = StringArray.new
  end

  def test_string_array_initialize
    assert_equal ["1", "2", "3"], StringArray.new([1, "2", :"3"])
  end

  def test_string_array_append
    @array << 1
    @array << "2"
    @array << :"3"
    assert_equal ["1", "2", "3"], @array
  end

  def test_string_array_concat
    @array.concat([1, "2"])
    @array.concat([:"3"])
    assert_equal ["1", "2", "3"], @array
  end

  def test_string_array_insert
    @array.insert(0, 1)
    @array.insert(1, "2")
    @array.insert(2, :"3")
    assert_equal ["1", "2", "3"], @array
  end

  def test_string_array_push
    @array.push(1)
    @array.push("2")
    @array.push(:"3")
    assert_equal ["1", "2", "3"], @array
  end

  def test_string_array_unshift
    @array.unshift(:"3")
    @array.unshift("2")
    @array.unshift(1)
    assert_equal ["1", "2", "3"], @array
  end
end
