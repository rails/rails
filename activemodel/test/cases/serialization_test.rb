require "cases/helper"

class SerializationTest < ActiveModel::TestCase
  class User
    include ActiveModel::Serialization

    attr_accessor :name, :email, :gender

    def attributes
      @attributes ||= {'name' => 'nil', 'email' => 'nil', 'gender' => 'nil'}
    end

    def foo
      'i_am_foo'
    end
  end

  setup do
    @user = User.new
    @user.name = 'David'
    @user.email = 'david@example.com'
    @user.gender = 'male'
  end

  def test_method_serializable_hash_should_work
    expected =  {"name"=>"David", "gender"=>"male", "email"=>"david@example.com"}
    assert_equal expected , @user.serializable_hash
  end

  def test_method_serializable_hash_should_work_with_only_option
    expected =  {"name"=>"David"}
    assert_equal expected , @user.serializable_hash(:only => [:name])
  end

  def test_method_serializable_hash_should_work_with_except_option
    expected =  {"gender"=>"male", "email"=>"david@example.com"}
    assert_equal expected , @user.serializable_hash(:except => [:name])
  end

  def test_method_serializable_hash_should_work_with_methods_option
    expected =  {"name"=>"David", "gender"=>"male", :foo=>"i_am_foo", "email"=>"david@example.com"}
    assert_equal expected , @user.serializable_hash(:methods => [:foo])
  end

end
