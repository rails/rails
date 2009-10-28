require 'abstract_unit'
require 'rails/initializable'

module InitializableTests

  class Foo
    extend Rails::Initializable

    class << self
      attr_accessor :foo, :bar
    end

    initializer :omg do
      @foo ||= 0
      @foo += 1
    end
  end

  class Bar < Foo
    initializer :bar do
      @bar ||= 0
      @bar += 1
    end
  end

  module Word
    extend Rails::Initializable

    initializer :word do
      $word = "bird"
    end
  end

  class Parent
    extend Rails::Initializable

    initializer :one do
      $arr << 1
    end

    initializer :two do
      $arr << 2
    end
  end

  class Child < Parent
    extend Rails::Initializable

    initializer :three, :before => :one do
      $arr << 3
    end

    initializer :four, :after => :one do
      $arr << 4
    end
  end

  class Parent
    initializer :five, :before => :one do
      $arr << 5
    end
  end

  class Instance
    include Rails::Initializable

    initializer :one do
      $arr << 1
    end

    initializer :two do
      $arr << 2
    end

    initializer :three, :global => true do
      $arr << 3
    end

    initializer :four, :global => true do
      $arr << 4
    end
  end

  class Basic < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    test "initializers run" do
      Foo.run_initializers
      assert_equal 1, Foo.foo
    end

    test "initializers are inherited" do
      Bar.run_initializers
      assert_equal [1, 1], [Bar.foo, Bar.bar]
    end

    test "initializers only get run once" do
      Foo.run_initializers
      Foo.run_initializers
      assert_equal 1, Foo.foo
    end

    test "running initializers on children does not effect the parent" do
      Bar.run_initializers
      assert_nil Foo.foo
      assert_nil Foo.bar
    end

    test "initializing with modules" do
      Word.run_initializers
      assert_equal "bird", $word
    end
  end

  class BeforeAfter < ActiveSupport::TestCase
    test "running on parent" do
      $arr = []
      Parent.run_initializers
      assert_equal [5, 1, 2], $arr
    end

    test "running on child" do
      $arr = []
      Child.run_initializers
      assert_equal [5, 3, 1, 4, 2], $arr
    end
  end

  class InstanceTest < ActiveSupport::TestCase
    test "running locals" do
      $arr = []
      instance = Instance.new
      instance.run_initializers
      assert_equal [1, 2], $arr
    end

    test "running globals" do
      $arr = []
      Instance.run_initializers
      assert_equal [3, 4], $arr
    end
  end
end