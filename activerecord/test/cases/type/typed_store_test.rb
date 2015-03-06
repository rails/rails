require "cases/helper"

module ActiveRecord
  module Type
    class TypedStoreTest < ActiveRecord::TestCase
      setup do
        @store_type = Serialized.new(Text.new, Coders::JSON)
        @yaml_type = Serialized.new(
          Text.new,
          Store::IndifferentCoder.new(Coders::YAMLColumn.new(Hash))
        )
      end

      def test_without_key_types
        type = TypedStore.new(@store_type)
        assert_equal [1, 2], type.cast([1, 2])
        assert_equal({ 'a' => 'b' }, type.cast('a' => 'b'))
        assert_equal [1, 2], type.deserialize('[1,2]')
        assert_equal({ 'a' => 'b' }, type.deserialize('{"a":"b"}'))
        assert_equal '[1,2]', type.serialize([1, 2])
        assert_equal '{"a":"b"}', type.serialize('a' => 'b')
      end

      def test_with_key_types
        type = TypedStore.new(@store_type)
        type.add_typed_key('date', :date)

        date = ::Date.new(2015, 3, 8)

        assert_equal({ 'date' => date }, type.cast(date: '2015-03-08'))
        assert_equal({ 'date' => date }, type.deserialize('{"date":"2015-03-08"}'))
        assert_equal '{"date":"2015-03-08"}', type.serialize(date: date)
      end

      def test_key_type_with_options
        type = TypedStore.new(@store_type)
        type.add_typed_key('val', :integer, limit: 1)

        assert_raises(::RangeError) do
          type.serialize(val: 1024)
        end
      end

      def test_create_from_type
        type = TypedStore.create_from_type(@store_type, 'date', :date)
        new_type = TypedStore.create_from_type(type, 'val', :integer)

        date = ::Date.new(2015, 3, 8)

        assert_equal({ 'date' => date, 'val' => '1.2' }, type.cast(date: '2015-03-08', val: '1.2'))
        assert_equal({ 'date' => date, 'val' => 1 }, new_type.cast(date: '2015-03-08', val: '1.2'))
      end

      def test_with_yaml_coder
        type = TypedStore.new(@yaml_type)
        type.add_typed_key('date', :date)

        date = ::Date.new(2015, 3, 8)

        assert_equal({ 'date' => date }, type.cast(date: '2015-03-08'))
        assert_equal({ 'date' => date }, type.cast('date' => '2015-03-08'))
        assert_equal({ 'date' => date }, type.deserialize("---\n:date: 2015-03-08\n"))
        assert_equal({ 'date' => date }, type.deserialize("---\ndate: 2015-03-08\n"))
        assert_equal "--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\ndate: 2015-03-08\n", type.serialize(date: date)
        assert_equal "--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\ndate: 2015-03-08\n", type.serialize('date' => date)
      end
    end
  end
end
