require "cases/helper"
require "active_support/core_ext/object/instance_variables"

class SerializationTest < ActiveModel::TestCase
  class User
    include ActiveModel::Serialization

    attr_accessor :name, :email, :gender, :address, :friends

    def initialize(name, email, gender)
      @name, @email, @gender = name, email, gender
      @friends = []
    end

    def attributes
      instance_values.except("address", "friends")
    end

    def method_missing(method_name, *args)
      if method_name == :bar
        "i_am_bar"
      else
        super
      end
    end

    def foo
      "i_am_foo"
    end
  end

  class Address
    include ActiveModel::Serialization

    attr_accessor :street, :city, :state, :zip

    def attributes
      instance_values
    end
  end

  setup do
    @user = User.new("David", "david@example.com", "male")
    @user.address = Address.new
    @user.address.street = "123 Lane"
    @user.address.city = "Springfield"
    @user.address.state = "CA"
    @user.address.zip = 11111
    @user.friends = [User.new("Joe", "joe@example.com", "male"),
                     User.new("Sue", "sue@example.com", "female")]
  end

  def test_method_serializable_hash_should_work
    expected = { "name" => "David", "gender" => "male", "email" => "david@example.com" }
    assert_equal expected, @user.serializable_hash
  end

  def test_method_serializable_hash_should_work_with_only_option
    expected = { "name" => "David" }
    assert_equal expected, @user.serializable_hash(only: [:name])
  end

  def test_method_serializable_hash_should_work_with_except_option
    expected = { "gender" => "male", "email" => "david@example.com" }
    assert_equal expected, @user.serializable_hash(except: [:name])
  end

  def test_method_serializable_hash_should_work_with_methods_option
    expected = { "name" => "David", "gender" => "male", "foo" => "i_am_foo", "bar" => "i_am_bar", "email" => "david@example.com" }
    assert_equal expected, @user.serializable_hash(methods: [:foo, :bar])
  end

  def test_method_serializable_hash_should_work_with_only_and_methods
    expected = { "foo" => "i_am_foo", "bar" => "i_am_bar" }
    assert_equal expected, @user.serializable_hash(only: [], methods: [:foo, :bar])
  end

  def test_method_serializable_hash_should_work_with_except_and_methods
    expected = { "gender" => "male", "foo" => "i_am_foo", "bar" => "i_am_bar" }
    assert_equal expected, @user.serializable_hash(except: [:name, :email], methods: [:foo, :bar])
  end

  def test_should_raise_NoMethodError_for_non_existing_method
    assert_raise(NoMethodError) { @user.serializable_hash(methods: [:nada]) }
  end

  def test_should_use_read_attribute_for_serialization
    def @user.read_attribute_for_serialization(n)
      "Jon"
    end

    expected = { "name" => "Jon" }
    assert_equal expected, @user.serializable_hash(only: :name)
  end

  def test_include_option_with_singular_association
    expected = { "name" => "David", "gender" => "male", "email" => "david@example.com",
                "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 } }
    assert_equal expected, @user.serializable_hash(include: :address)
  end

  def test_include_option_with_plural_association
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                           { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }] }
    assert_equal expected, @user.serializable_hash(include: :friends)
  end

  def test_include_option_with_empty_association
    @user.friends = []
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David", "friends" => [] }
    assert_equal expected, @user.serializable_hash(include: :friends)
  end

  class FriendList
    def initialize(friends)
      @friends = friends
    end

    def to_ary
      @friends
    end
  end

  def test_include_option_with_ary
    @user.friends = FriendList.new(@user.friends)
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                           { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }] }
    assert_equal expected, @user.serializable_hash(include: :friends)
  end

  def test_multiple_includes
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 },
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                           { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }] }
    assert_equal expected, @user.serializable_hash(include: [:address, :friends])
  end

  def test_include_with_options
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "address" => { "street" => "123 Lane" } }
    assert_equal expected, @user.serializable_hash(include: { address: { only: "street" } })
  end

  def test_nested_include
    @user.friends.first.friends = [@user]
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male",
                            "friends" => [{ "email" => "david@example.com", "gender" => "male", "name" => "David" }] },
                            { "name" => "Sue", "email" => "sue@example.com", "gender" => "female", "friends" => [] }] }
    assert_equal expected, @user.serializable_hash(include: { friends: { include: :friends } })
  end

  def test_only_include
    expected = { "name" => "David", "friends" => [{ "name" => "Joe" }, { "name" => "Sue" }] }
    assert_equal expected, @user.serializable_hash(only: :name, include: { friends: { only: :name } })
  end

  def test_except_include
    expected = { "name" => "David", "email" => "david@example.com",
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com" },
                             { "name" => "Sue", "email" => "sue@example.com" }] }
    assert_equal expected, @user.serializable_hash(except: :gender, include: { friends: { except: :gender } })
  end

  def test_multiple_includes_with_options
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "address" => { "street" => "123 Lane" },
                "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                           { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }] }
    assert_equal expected, @user.serializable_hash(include: [{ address: { only: "street" } }, :friends])
  end
end
