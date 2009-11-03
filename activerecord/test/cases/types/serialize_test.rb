require "cases/helper"

class SerializeTest < ActiveRecord::TestCase

  test "typecast" do
    serializer = ActiveRecord::Type::Serialize.new(column = nil, :serialize => Array)

    assert_equal [],    serializer.cast([].to_yaml)
    assert_equal ['1'], serializer.cast(['1'].to_yaml)
    assert_equal nil,   serializer.cast(nil.to_yaml)
  end

  test "cast as boolean" do
    serializer = ActiveRecord::Type::Serialize.new(column = nil, :serialize => Array)

    assert_equal true,  serializer.boolean(['1'].to_yaml)
    assert_equal false, serializer.boolean([].to_yaml)
  end

end