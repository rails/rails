require "cases/helper"

class SerializerTest < ActiveModel::TestCase
  class User
    attr_accessor :superuser

    def super_user?
      @superuser
    end

    def read_attribute_for_serialization(name)
      hash = { :first_name => "Jose", :last_name => "Valim", :password => "oh noes yugive my password" }
      hash[name]
    end
  end

  class UserSerializer < ActiveModel::Serializer
    attributes :first_name, :last_name
  end

  class User2Serializer < ActiveModel::Serializer
    attributes :first_name, :last_name

    def serializable_hash(*)
      attributes.merge(:ok => true).merge(scope)
    end
  end

  class MyUserSerializer < ActiveModel::Serializer
    attributes :first_name, :last_name

    def serializable_hash(*)
      hash = attributes
      hash = hash.merge(:super_user => true) if my_user.super_user?
      hash
    end
  end

  def test_attributes
    user = User.new
    user_serializer = UserSerializer.new(user, nil)

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim" }, hash)
  end

  def test_attributes_method
    user = User.new
    user_serializer = User2Serializer.new(user, {})

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :ok => true }, hash)
  end

  def test_serializer_receives_scope
    user = User.new
    user_serializer = User2Serializer.new(user, {:scope => true})

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :ok => true, :scope => true }, hash)
  end

  def test_pretty_accessors
    user = User.new
    user.superuser = true
    user_serializer = MyUserSerializer.new(user, nil)

    hash = user_serializer.as_json

    assert_equal({ :first_name => "Jose", :last_name => "Valim", :super_user => true }, hash)
  end
end
