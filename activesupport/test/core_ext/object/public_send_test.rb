require 'abstract_unit'
require 'active_support/core_ext/object/public_send'

module PublicSendReceiver
  def receive_public_method(*args)
    return args + [yield]
  end

  protected

  def receive_protected_method(*args)
    return args + [yield]
  end

  private

  def receive_private_method(*args)
    return args + [yield]
  end
end

# Note, running this on 1.9 will be testing the Ruby core implementation, but it is good to
# do this to ensure that our backport functions the same as Ruby core in 1.9
class PublicSendTest < Test::Unit::TestCase
  def instance
    @instance ||= begin
      klass = Class.new do
        include PublicSendReceiver
      end
      klass.new
    end
  end

  def singleton_instance
    @singleton_instance ||= begin
      object = Object.new
      object.singleton_class.send(:include, PublicSendReceiver)
      object
    end
  end

  def test_should_receive_public_method
    assert_equal(
      [:foo, :bar, :baz],
      instance.public_send(:receive_public_method, :foo, :bar) { :baz }
    )
  end

  def test_should_receive_public_singleton_method
    assert_equal(
      [:foo, :bar, :baz],
      singleton_instance.public_send(:receive_public_method, :foo, :bar) { :baz }
    )
  end

  def test_should_raise_on_protected_method
    assert_raises(NoMethodError) do
      instance.public_send(:receive_protected_method, :foo, :bar) { :baz }
    end
  end

  def test_should_raise_on_protected_singleton_method
    assert_raises(NoMethodError) do
      singleton_instance.public_send(:receive_protected_method, :foo, :bar) { :baz }
    end
  end

  def test_should_raise_on_private_method
    assert_raises(NoMethodError) do
      instance.public_send(:receive_private_method, :foo, :bar) { :baz }
    end
  end

  def test_should_raise_on_singleton_private_method
    assert_raises(NoMethodError) do
      singleton_instance.public_send(:receive_private_method, :foo, :bar) { :baz }
    end
  end

  def test_should_raise_on_undefined_method
    assert_raises(NoMethodError) do
      instance.public_send(:receive_undefined_method, :foo, :bar) { :baz }
    end
  end

  def test_protected_method_message
    instance.public_send(:receive_protected_method, :foo, :bar) { :baz }
  rescue NoMethodError => exception
    assert_equal(
      "protected method `receive_protected_method' called for #{instance.inspect}",
      exception.message
    )
  end

  def test_private_method_message
    instance.public_send(:receive_private_method, :foo, :bar) { :baz }
  rescue NoMethodError => exception
    assert_equal(
      "private method `receive_private_method' called for #{instance.inspect}",
      exception.message
    )
  end

  def test_undefined_method_message
    instance.public_send(:receive_undefined_method, :foo, :bar) { :baz }
  rescue NoMethodError => exception
    assert_equal(
      "undefined method `receive_undefined_method' for #{instance.inspect}",
      exception.message
    )
  end

  def test_receiver_with_no_singleton
    assert_equal "5", 5.public_send(:to_s)
    assert_equal "foo", :foo.public_send(:to_s)
  end
end
