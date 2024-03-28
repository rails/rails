# frozen_string_literal: true

require "cases/helper"
require "models/user"

module ActiveModel
  module Type
    class CollectionTest < ActiveModel::TestCase
      setup do
        @element_type = Minitest::Mock.new
        @serializer = Minitest::Mock.new
        ActiveModel::Type.stub(:lookup, @element_type) do
          @collection = Collection.new(element_type: :element_type, serializer: @serializer)
        end
        @my_collection = [1, 2, 3]
      end

      test "#valid_value? returns false if value is not an array" do
        assert_not @collection.valid_value?("Nikita")
      end

      test "#valid_value? returns false if value is not an array of valid type_objects" do
        @element_type.expect(:valid_value?, false, ["Nikita"])
        assert_not @collection.valid_value?(["Nikita"])
      end

      test "#assert_valid_value doesn't raise if valid_value? returns true" do
        assert_nothing_raised do
          @collection.stub(:valid_value?, true) do
            @collection.assert_valid_value(["Nikita"])
          end
        end
      end

      test "#assert_valid_value raises ArgumentError if valid_value? returns false" do
        err = assert_raises(ArgumentError) do
          @collection.stub(:valid_value?, false) do
            @collection.assert_valid_value({ name: "Nikita" })
          end
        end

        assert_equal "'{:name=>\"Nikita\"}' is not a valid collection of element_type", err.message
      end

      test "#valid_value? delegates valid_value? check to the element type" do
        @my_collection.each { |i| @element_type.expect(:valid_value?, true, [i]) }
        assert @collection.valid_value?(@my_collection)
      end

      test "#serialize delegates serialize check to the element type" do
        serialized_items = @my_collection.map { |i| "serialized #{i}" }
        @my_collection.each_with_index do |item, index|
          @element_type.expect(:serialize, serialized_items[index], [item])
        end
        expected = "serialized_collection: #{serialized_items}"
        @serializer.expect(:encode, expected, [serialized_items])
        assert_equal expected, @collection.serialize(@my_collection)
      end

      test "#deserialize delegates deserialize check to the element type" do
        serialized_collection = "serialized collection"
        @my_collection.each { |i| @element_type.expect(:deserialize, "deserialized #{i}", [i]) }
        expected = @my_collection.map { |i| "deserialized #{i}" }
        @serializer.expect(:decode, @my_collection, [serialized_collection])

        assert_equal expected, @collection.deserialize(serialized_collection)
      end

      test "#serializable? delegates serializable? check to the element type" do
        @my_collection.each { |i| @element_type.expect(:serializable?, true, [i]) }
        assert @collection.serializable?(@my_collection)
      end

      test "#changed_in_place? delegates changed_in_place? check to the element type" do
        my_collection_raw = "my_serialized_collection"
        @my_collection.each do |el|
          @element_type.expect(:changed_in_place?, false, [el, el])
        end

        @collection.stub(:deserialize, @my_collection, [my_collection_raw]) do
          assert_not @collection.changed_in_place?(my_collection_raw, @my_collection)
        end
      end

      test "#changed_in_place? returns true if size of new and old collections is different" do
        my_collection_raw = "my_serialized_collection"

        @collection.stub(:deserialize, @my_collection, [my_collection_raw]) do
          assert @collection.changed_in_place?(my_collection_raw, [1])
        end
      end

      test "#changed_in_place? returns true if collections are the same size but with different elements" do
        new_collection = [1, "changed", 3]
        my_collection_raw = "my_serialized_collection"
        @element_type.expect(:changed_in_place?, false, [1, 1])
        @element_type.expect(:changed_in_place?, true, [2, "changed"])

        @collection.stub(:deserialize, @my_collection, [my_collection_raw]) do
          assert @collection.changed_in_place?(my_collection_raw, new_collection)
        end
      end

      test "#cast returns an empty array if value is nil" do
        assert_equal [], @collection.cast(nil)
      end

      test "#cast wraps false value in an array" do
        @element_type.expect(:cast, false, [false])
        assert_equal [false], @collection.cast(false)
      end

      test "#cast wraps value in an array if value is not an array" do
        @element_type.expect(:cast, 1, [1])
        assert_equal [1], @collection.cast(1)
      end

      test "#cast delegates cast to the element type" do
        string_collection = ["1", "2", "3"]
        string_collection.each { |el| @element_type.expect(:cast, el.to_i, [el]) }

        assert_equal @my_collection, @collection.cast(string_collection)
      end
    end
  end
end
