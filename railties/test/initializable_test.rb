require 'abstract_unit'
require 'rails/initializable'

module InitializableTests

  class Foo
    include Rails::Initializable

    class << self
      attr_accessor :foo, :bar
    end

    initializer :omg, :global => true do
      @foo ||= 0
      @foo += 1
    end
  end

  class Bar < Foo
    initializer :bar, :global => true do
      @bar ||= 0
      @bar += 1
    end
  end

  module Word
    include Rails::Initializable

    initializer :word, :global => true do
      $word = "bird"
    end
  end

  class Parent
    include Rails::Initializable

    initializer :one, :global => true do
      $arr << 1
    end

    initializer :two, :global => true do
      $arr << 2
    end
  end

  class Child < Parent
    include Rails::Initializable

    initializer :three, :before => :one, :global => true do
      $arr << 3
    end

    initializer :four, :after => :one, :global => true do
      $arr << 4
    end
  end

  class Parent
    initializer :five, :before => :one, :global => true do
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

  class WithArgs
    include Rails::Initializable

    initializer :foo do |arg|
      $with_arg = arg
    end
  end

  class OverriddenInitializer
    class MoreInitializers
      include Rails::Initializable

      initializer :startup, :before => :last do
        $arr << 3
      end

      initializer :terminate, :after => :first do
        $arr << two
      end

      def two
        2
      end
    end

    include Rails::Initializable

    initializer :first do
      $arr << 1
    end

    initializer :last do
      $arr << 4
    end

    def self.initializers
      super + MoreInitializers.new.initializers
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

  class WithArgsTest < ActiveSupport::TestCase
    test "running initializers with args" do
      $with_arg = nil
      WithArgs.new.run_initializers('foo')
      assert_equal 'foo', $with_arg
    end
  end

  class OverriddenInitializerTest < ActiveSupport::TestCase
    test "merges in the initializers from the parent in the right order" do
      $arr = []
      OverriddenInitializer.new.run_initializers
      assert_equal [1, 2, 3, 4], $arr
    end
  end
end