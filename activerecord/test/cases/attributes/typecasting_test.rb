require "cases/helper"

class TypecastingTest < ActiveRecord::TestCase

  class TypecastingAttributes < Hash
    include ActiveRecord::Attributes::Typecasting
  end

  module MockType
    class Object

      def cast(value)
        value
      end

      def precast(value)
        value
      end

      def boolean(value)
        !value.blank?
      end

      def appendable?
        false
      end

    end

    class Integer < Object

      def cast(value)
        value.to_i
      end

      def precast(value)
        value ? value : 0
      end

      def boolean(value)
        !Float(value).zero?
      end

    end

    class Serialize < Object

      def cast(value)
        YAML::load(value) rescue value
      end

      def precast(value)
        value
      end

      def appendable?
        true
      end

    end
  end

  def setup
    @attributes = TypecastingAttributes.new
    @attributes.types.default = MockType::Object.new
    @attributes.types['comments_count'] = MockType::Integer.new
  end

  test "typecast on read" do
    attributes = @attributes.merge('comments_count' => '5')
    assert_equal 5, attributes['comments_count']
  end

  test "typecast on write" do
    @attributes['comments_count'] = false

    assert_equal 0, @attributes.to_h['comments_count']
  end

  test "serialized objects" do
    attributes = @attributes.merge('tags' => [ 'peanut butter' ].to_yaml)
    attributes.types['tags'] = MockType::Serialize.new
    attributes['tags'] << 'jelly'

    assert_equal [ 'peanut butter', 'jelly' ], attributes['tags']
  end

  test "without typecasting" do
    @attributes.merge!('comments_count' => '5')
    attributes = @attributes.without_typecast
    
    assert_equal '5', attributes['comments_count']
    assert_equal  5,  @attributes['comments_count'], "Original attributes should typecast"
  end


  test "typecast all attributes" do
    attributes = @attributes.merge('title' => 'I love sandwiches', 'comments_count' => '5')
    attributes.typecast!

    assert_equal({ 'title' => 'I love sandwiches', 'comments_count' => 5 }, attributes)
  end

  test "query for has? value" do
    attributes = @attributes.merge('comments_count' => '1')

    assert_equal true,  attributes.has?('comments_count')
    attributes['comments_count'] = '0'
    assert_equal false,  attributes.has?('comments_count')
  end

  test "attributes to Hash" do
    attributes_hash = { 'title' => 'I love sandwiches', 'comments_count' => '5' }
    attributes = @attributes.merge(attributes_hash)

    assert_equal Hash, attributes.to_h.class
    assert_equal attributes_hash, attributes.to_h
  end

end
