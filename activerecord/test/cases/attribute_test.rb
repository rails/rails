require 'cases/helper'
require 'minitest/mock'

module ActiveRecord
  class AttributeTest < ActiveRecord::TestCase
    setup do
      @type = MiniTest::Mock.new
    end

    teardown do
      assert @type.verify
    end

    test "from_database + read type casts from database" do
      @type.expect(:type_cast_from_database, 'type cast from database', ['a value'])
      attribute = Attribute.from_database('a value', @type)

      type_cast_value = attribute.value

      assert_equal 'type cast from database', type_cast_value
    end

    test "from_user + read type casts from user" do
      @type.expect(:type_cast_from_user, 'type cast from user', ['a value'])
      attribute = Attribute.from_user('a value', @type)

      type_cast_value = attribute.value

      assert_equal 'type cast from user', type_cast_value
    end

    test "reading memoizes the value" do
      @type.expect(:type_cast_from_database, 'from the database', ['whatever'])
      attribute = Attribute.from_database('whatever', @type)

      type_cast_value = attribute.value
      second_read = attribute.value

      assert_equal 'from the database', type_cast_value
      assert_same type_cast_value, second_read
    end

    test "reading memoizes falsy values" do
      @type.expect(:type_cast_from_database, false, ['whatever'])
      attribute = Attribute.from_database('whatever', @type)

      attribute.value
      attribute.value
    end

    test "read_before_typecast returns the given value" do
      attribute = Attribute.from_database('raw value', @type)

      raw_value = attribute.value_before_type_cast

      assert_equal 'raw value', raw_value
    end

    test "from_database + read_for_database type casts to and from database" do
      @type.expect(:type_cast_from_database, 'read from database', ['whatever'])
      @type.expect(:type_cast_for_database, 'ready for database', ['read from database'])
      attribute = Attribute.from_database('whatever', @type)

      type_cast_for_database = attribute.value_for_database

      assert_equal 'ready for database', type_cast_for_database
    end

    test "from_user + read_for_database type casts from the user to the database" do
      @type.expect(:type_cast_from_user, 'read from user', ['whatever'])
      @type.expect(:type_cast_for_database, 'ready for database', ['read from user'])
      attribute = Attribute.from_user('whatever', @type)

      type_cast_for_database = attribute.value_for_database

      assert_equal 'ready for database', type_cast_for_database
    end

    test "duping dups the value" do
      @type.expect(:type_cast_from_database, 'type cast', ['a value'])
      attribute = Attribute.from_database('a value', @type)

      value_from_orig = attribute.value
      value_from_clone = attribute.dup.value
      value_from_orig << ' foo'

      assert_equal 'type cast foo', value_from_orig
      assert_equal 'type cast', value_from_clone
    end

    test "duping does not dup the value if it is not dupable" do
      @type.expect(:type_cast_from_database, false, ['a value'])
      attribute = Attribute.from_database('a value', @type)

      assert_same attribute.value, attribute.dup.value
    end

    test "duping does not eagerly type cast if we have not yet type cast" do
      attribute = Attribute.from_database('a value', @type)
      attribute.dup
    end

    class MyType
      def type_cast_from_user(value)
        value + " from user"
      end

      def type_cast_from_database(value)
        value + " from database"
      end
    end

    test "with_value_from_user returns a new attribute with the value from the user" do
      old = Attribute.from_database("old", MyType.new)
      new = old.with_value_from_user("new")

      assert_equal "old from database", old.value
      assert_equal "new from user", new.value
    end

    test "with_value_from_database returns a new attribute with the value from the database" do
      old = Attribute.from_user("old", MyType.new)
      new = old.with_value_from_database("new")

      assert_equal "old from user", old.value
      assert_equal "new from database", new.value
    end
  end
end
