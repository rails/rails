# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/instance_variables"

class SerializationTest < ActiveModel::TestCase
  class User
    include ActiveModel::Serialization

    attr_accessor :name, :email, :gender, :address, :friends, :active, :admin, :age

    def initialize(name, email, gender)
      @name, @email, @gender = name, email, gender
      @friends = []
      @active = true
      @admin = false
      @age = 30
    end

    def attributes
      instance_values.except("address", "friends", "active", "admin", "age")
    end

    def method_missing(method_name, ...)
      if method_name == :bar
        "i_am_bar"
      else
        super
      end
    end

    def foo
      "i_am_foo"
    end

    def adult?
      age >= 18
    end

    def child?
      !adult?
    end

    def admin?
      admin
    end

    def active?
      active
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

    # Friends need active and admin attributes for our tests
    joe = User.new("Joe", "joe@example.com", "male")
    joe.active = true
    joe.admin = false

    sue = User.new("Sue", "sue@example.com", "female")
    sue.active = true
    sue.admin = false

    @user.friends = [joe, sue]

    # Make sure user has default values for conditional tests
    @user.active = true
    @user.admin = false
  end

  def test_method_serializable_hash_should_work
    expected = { "name" => "David", "gender" => "male", "email" => "david@example.com" }
    assert_equal expected, @user.serializable_hash
  end

  def test_method_serializable_hash_should_work_with_only_option
    expected = { "name" => "David" }
    assert_equal expected, @user.serializable_hash(only: [:name])
  end

  def test_method_serializable_hash_should_work_with_only_option_with_order_of_given_keys
    expected = { "name" => "David", "email" => "david@example.com" }
    assert_equal expected.keys, @user.serializable_hash(only: [:name, :email]).keys
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

  def test_all_includes_with_options
    expected = { "email" => "david@example.com", "gender" => "male", "name" => "David",
                "address" => { "street" => "123 Lane" },
                "friends" => [{ "name" => "Joe" }, { "name" => "Sue" }] }
    assert_equal expected, @user.serializable_hash(include: [address: { only: "street" }, friends: { only: "name" }])
  end

  # Test conditional includes with :if option as symbol
  def test_serializable_hash_with_if_option_as_symbol
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # When condition is true, include the association
    @user.admin = true
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )
    result = @user.serializable_hash(include: { address: { if: :admin? } })
    assert_equal expected_with_address, result

    # When condition is false, don't include the association
    @user.admin = false
    result = @user.serializable_hash(include: { address: { if: :admin? } })
    assert_equal expected, result
  end

  # Test conditional includes with :unless option as symbol
  def test_serializable_hash_with_unless_option_as_symbol
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # When condition is false, include the association
    @user.admin = false
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )
    result = @user.serializable_hash(include: { address: { unless: :admin? } })
    assert_equal expected_with_address, result

    # When condition is true, don't include the association
    @user.admin = true
    result = @user.serializable_hash(include: { address: { unless: :admin? } })
    assert_equal expected, result
  end

  # Test conditional includes with :if option as proc
  def test_serializable_hash_with_if_option_as_proc
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # When condition is true, include the association
    @user.admin = true
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )
    result = @user.serializable_hash(include: { address: { if: -> { admin } } })
    assert_equal expected_with_address, result

    # When condition is false, don't include the association
    @user.admin = false
    result = @user.serializable_hash(include: { address: { if: -> { admin } } })
    assert_equal expected, result
  end

  # Test conditional includes with :unless option as proc
  def test_serializable_hash_with_unless_option_as_proc
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # When condition is false, include the association
    @user.admin = false
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )
    result = @user.serializable_hash(include: { address: { unless: -> { admin } } })
    assert_equal expected_with_address, result

    # When condition is true, don't include the association
    @user.admin = true
    result = @user.serializable_hash(include: { address: { unless: -> { admin } } })
    assert_equal expected, result
  end

  # Test with both :if and :unless conditions
  def test_serializable_hash_with_both_if_and_unless_options
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # Both conditions satisfied (if: true, unless: false) - include the association
    @user.admin = true
    @user.active = true
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )
    result = @user.serializable_hash(include: { address: { if: :admin?, unless: -> { !active } } })
    assert_equal expected_with_address, result

    # if condition is false - don't include the association
    @user.admin = false
    @user.active = true
    result = @user.serializable_hash(include: { address: { if: :admin?, unless: -> { !active } } })
    assert_equal expected, result

    # unless condition is true - don't include the association
    @user.admin = true
    @user.active = false
    result = @user.serializable_hash(include: { address: { if: :admin?, unless: -> { !active } } })
    assert_equal expected, result

    # Both conditions not satisfied (if: false, unless: true) - don't include the association
    @user.admin = false
    @user.active = false
    result = @user.serializable_hash(include: { address: { if: :admin?, unless: -> { !active } } })
    assert_equal expected, result
  end

  # Test conditional includes with collections
  def test_serializable_hash_with_conditional_includes_on_collections
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male", "friends" => [] }

    # When condition is true, include the association
    @user.admin = true
    expected_with_friends = expected.merge(
      "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                 { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }]
    )
    result = @user.serializable_hash(include: { friends: { if: :admin? } })
    assert_equal expected_with_friends, result

    # When condition is false, don't include the association
    @user.admin = false
    result = @user.serializable_hash(include: { friends: { if: :admin? } })
    assert_equal expected, result
  end

  # Test with nested conditional includes
  def test_serializable_hash_with_nested_conditional_includes
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male", "friends" => [] }

    # Set up a complex scenario with nested associations and conditions
    @user.admin = true
    @user.friends.first.friends = [@user]
    @user.friends.first.admin = true

    # The nested result when all conditions are true
    expected_with_nested = expected.merge(
      "friends" => [
        {
          "name" => "Joe",
          "email" => "joe@example.com",
          "gender" => "male",
          "friends" => [{ "name" => "David", "email" => "david@example.com", "gender" => "male" }]
        },
        {
          "name" => "Sue",
          "email" => "sue@example.com",
          "gender" => "female",
          "friends" => []
        }
      ]
    )

    # Execute serialization with nested conditions
    result = @user.serializable_hash(include: {
      friends: {
        if: :admin?,
        include: {
          friends: {
            if: :admin?
          }
        }
      }
    })

    assert_equal expected_with_nested, result

    # When outer condition is false, don't include any associations
    @user.admin = false
    result = @user.serializable_hash(include: {
      friends: {
        if: :admin?,
        include: {
          friends: {
            if: :admin?
          }
        }
      }
    })

    assert_equal expected, result

    # When inner condition is false on first friend, don't include nested associations
    @user.admin = true
    @user.friends.first.admin = false
    expected_with_outer_only = expected.merge(
      "friends" => [
        {
          "name" => "Joe",
          "email" => "joe@example.com",
          "gender" => "male",
          "friends" => []
        },
        {
          "name" => "Sue",
          "email" => "sue@example.com",
          "gender" => "female",
          "friends" => []
        }
      ]
    )

    result = @user.serializable_hash(include: {
      friends: {
        if: :admin?,
        include: {
          friends: {
            if: :admin?
          }
        }
      }
    })

    # Check that the nested association is empty because of the condition
    assert_equal [], result["friends"][0]["friends"]
    assert_equal expected_with_outer_only, result
  end

  # Test nested includes with conditions
  def test_nested_include_with_conditions
    # Set up user's friend relationships for testing
    friend1 = @user.friends.first
    friend1.friends = [@user]
    friend1.active = false  # This friend is inactive - if: :active? will be false

    friend2 = @user.friends[1]
    friend2.friends = []

    result = @user.serializable_hash(include: { friends: { include: { friends: { if: :active? } } } })

    # First friend should not have friends in the result since active is false and we use if: :active?
    assert_equal "Joe", result["friends"][0]["name"]
    assert_equal [], result["friends"][0]["friends"]

    # Second friend should have empty friends array
    assert_equal "Sue", result["friends"][1]["name"]
    assert_equal [], result["friends"][1]["friends"]

    # Test overall structure is as expected
    assert_equal 2, result["friends"].size
    assert_equal "David", result["name"]
  end

  # Test conditional includes with reused data
  def test_serializable_hash_reuses_conditional_include
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # Create a reusable include option hash
    include_opts = { address: { if: :admin? } }

    # When condition is true, include the association
    @user.admin = true
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )

    # Serialize with the reusable include option
    result1 = @user.serializable_hash(include: include_opts)
    assert_equal expected_with_address, result1

    # Change the condition state and serialize again with the same options
    @user.admin = false
    result2 = @user.serializable_hash(include: include_opts)
    assert_equal expected, result2

    # Verify the include_opts hash hasn't been modified
    assert_equal({ address: { if: :admin? } }, include_opts)
  end

  # Test with complex conditions in both :if and :unless
  def test_serializable_hash_with_complex_conditions
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # Define a complex if condition - both age and admin status
    complex_if_proc = -> { age > 25 && admin? }

    # Define a complex unless condition - name length
    complex_unless_proc = -> { name.length < 4 } # David has 5 letters

    # Set up conditions for test
    @user.age = 30
    @user.admin = true

    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 }
    )

    # Test with complex conditions, should include address
    result = @user.serializable_hash(include: {
      address: {
        if: complex_if_proc,
        unless: complex_unless_proc
      }
    })
    assert_equal expected_with_address, result

    # Change age to fail the if condition
    @user.age = 20
    result = @user.serializable_hash(include: {
      address: {
        if: complex_if_proc,
        unless: complex_unless_proc
      }
    })
    assert_equal expected, result

    # Change name to trigger the unless condition
    @user.name = "Bob" # 3 letters
    @user.age = 30 # restore age to pass if condition
    result = @user.serializable_hash(include: {
      address: {
        if: complex_if_proc,
        unless: complex_unless_proc
      }
    })
    # Name changed, so expected needs to be updated
    expected = { "name" => "Bob", "email" => "david@example.com", "gender" => "male" }
    assert_equal expected, result
  end

  # Test with multiple conditional associations
  def test_serializable_hash_with_multiple_conditional_includes
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    # Set up conditions for test
    @user.admin = true
    @user.active = false

    # Test with multiple associations with different conditions
    result = @user.serializable_hash(include: {
      address: { if: :admin? },
      friends: { if: :active? }
    })

    # Only address should be included because admin is true but active is false
    expected_with_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 },
      "friends" => []
    )
    assert_equal expected_with_address, result
    assert_equal [], result["friends"]

    # Change conditions and test again
    @user.admin = false
    @user.active = true

    result = @user.serializable_hash(include: {
      address: { if: :admin? },
      friends: { if: :active? }
    })

    # Only friends should be included because admin is false but active is true
    expected_with_friends = expected.merge(
      "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                 { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }]
    )
    assert_equal expected_with_friends, result
    assert_nil result["address"]

    # With both conditions true, both associations should be included
    @user.admin = true
    @user.active = true

    result = @user.serializable_hash(include: {
      address: { if: :admin? },
      friends: { if: :active? }
    })

    expected_with_both = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA", "zip" => 11111 },
      "friends" => [{ "name" => "Joe", "email" => "joe@example.com", "gender" => "male" },
                 { "name" => "Sue", "email" => "sue@example.com", "gender" => "female" }]
    )
    assert_equal expected_with_both, result
  end

  # Test with conditional includes and other options (only, except)
  def test_serializable_hash_with_conditionals_and_other_options
    expected = { "name" => "David", "email" => "david@example.com", "gender" => "male" }

    @user.admin = true

    # Test with conditional include combined with only option
    result = @user.serializable_hash(include: {
      address: {
        if: :admin?,
        only: [:street, :city]
      }
    })

    expected_with_partial_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield" }
    )
    assert_equal expected_with_partial_address, result

    # Test with conditional include combined with except option
    result = @user.serializable_hash(include: {
      address: {
        if: :admin?,
        except: [:zip]
      }
    })

    expected_with_partial_address = expected.merge(
      "address" => { "street" => "123 Lane", "city" => "Springfield", "state" => "CA" }
    )
    assert_equal expected_with_partial_address, result

    # When condition is false, association should not be included regardless of other options
    @user.admin = false

    result = @user.serializable_hash(include: {
      address: {
        if: :admin?,
        only: [:street, :city]
      }
    })
    assert_equal expected, result
  end
end
