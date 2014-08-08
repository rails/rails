require 'abstract_unit'

class PerishableSerializerTest < ActiveSupport::TestCase
  class NullSerializer
    def self.load(value)
      value
    end

    def self.dump(value)
      value
    end
  end

  def setup
    @serializer = ActiveSupport::PerishableSerializer.new(NullSerializer)
  end

  # test the output of the dump, it should start with '\0' with the format '\0--expiration--value'
  def test_output_with_expiration
    data = @serializer.dump("value", 1.hour.from_now)
    assert data.start_with?("\0")
    assert_equal 3, data.split("--").size
  end

  def test_value_with_double_dash
    data = @serializer.dump("value--value--value", 1.hour.from_now)
    assert_equal "value--value--value", @serializer.load(data)
  end

  def test_without_expiration
    data = @serializer.dump("value")
    assert_equal "value", @serializer.load(data)
  end

  def test_expiration
    data = @serializer.dump("value", 1.hour.from_now)
    assert_equal "value", @serializer.load(data)

    travel 59.minutes

    assert_equal "value", @serializer.load(data)

    travel 1.minute

    assert_raise(ActiveSupport::PerishableSerializer::ExpiredMessage) do
      @serializer.load(data)
    end
  end
end