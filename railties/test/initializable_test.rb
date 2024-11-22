# frozen_string_literal: true

require "abstract_unit"
require "rails/initializable"

module InitializableTests
  class Foo
    include Rails::Initializable
    attr_accessor :foo, :bar

    initializer :start do
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

  class Parent
    include Rails::Initializable

    initializer :one do
      $arr << 1
    end

    initializer :two do
      $arr << 2
    end
  end

  class Child < Parent
    include Rails::Initializable

    initializer :three, before: :one do
      $arr << 3
    end

    initializer :four, after: :one, before: :two do
      $arr << 4
    end
  end

  class Parent
    initializer :five, before: :one do
      $arr << 5
    end
  end

  class Instance
    include Rails::Initializable

    initializer :one, group: :assets do
      $arr << 1
    end

    initializer :two do
      $arr << 2
    end

    initializer :three, group: :all do
      $arr << 3
    end

    initializer :four do
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

      initializer :startup, before: :last do
        $arr << 3
      end

      initializer :terminate, after: :first, before: :startup do
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

  module Interdependent
    class PluginA
      include Rails::Initializable

      initializer "plugin_a.startup" do
        $arr << 1
      end

      initializer "plugin_a.terminate" do
        $arr << 4
      end
    end

    class PluginB
      include Rails::Initializable

      initializer "plugin_b.startup", after: "plugin_a.startup" do
        $arr << 2
      end

      initializer "plugin_b.terminate", before: "plugin_a.terminate" do
        $arr << 3
      end
    end

    class Application
      include Rails::Initializable
      def self.initializers
        PluginB.initializers + PluginA.initializers
      end
    end
  end

  module Duplicate
    class PluginA
      include Rails::Initializable

      initializer "plugin_a.startup" do
        $arr << 1
      end

      initializer "plugin_a.terminate" do
        $arr << 4
      end
    end

    class PluginB
      include Rails::Initializable

      initializer "plugin_b.startup", after: "plugin_a.startup" do
        $arr << 2
      end

      initializer "plugin_b.terminate", before: "plugin_a.terminate" do
        $arr << 3
      end
    end

    class Application
      include Rails::Initializable

      def self.initializers
        @initializers ||= (PluginA.initializers + PluginB.initializers + PluginB.initializers)
      end

      initializer "root" do
        $arr << 5
      end
    end
  end

  class Basic < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    test "initializers run" do
      foo = Foo.new
      foo.run_initializers
      assert_equal 1, foo.foo
    end

    test "initializers are inherited" do
      bar = Bar.new
      bar.run_initializers
      assert_equal [1, 1], [bar.foo, bar.bar]
    end

    test "initializers only get run once" do
      foo = Foo.new
      foo.run_initializers
      foo.run_initializers
      assert_equal 1, foo.foo
    end

    test "creating initializer without a block raises an error" do
      assert_raise(ArgumentError) do
        Class.new do
          include Rails::Initializable

          initializer :foo
        end
      end
    end

    test "Initializer provides context's class name" do
      foo = Foo.new
      assert_equal foo.class, foo.initializers.first.context_class
    end
  end

  class BeforeAfter < ActiveSupport::TestCase
    test "running on parent" do
      $arr = []
      Parent.new.run_initializers
      assert_equal [5, 1, 2], $arr
    end

    test "running on child" do
      $arr = []
      Child.new.run_initializers
      assert_equal [5, 3, 1, 4, 2], $arr
    end

    test "handles dependencies introduced before all initializers are loaded" do
      $arr = []
      Interdependent::Application.new.run_initializers
      assert_equal [1, 2, 3, 4], $arr
    end

    test "handles duplicate initializers" do
      $arr = []
      Duplicate::Application.new.run_initializers
      assert_equal [1, 2, 2, 3, 3, 4, 5], $arr
    end
  end

  class InstanceTest < ActiveSupport::TestCase
    test "running locals" do
      $arr = []
      instance = Instance.new
      instance.run_initializers
      assert_equal [2, 3, 4], $arr
    end

    test "running locals with groups" do
      $arr = []
      instance = Instance.new
      instance.run_initializers(:assets)
      assert_equal [1, 3], $arr
    end
  end

  class WithArgsTest < ActiveSupport::TestCase
    test "running initializers with args" do
      $with_arg = nil
      WithArgs.new.run_initializers(:default, "foo")
      assert_equal "foo", $with_arg
    end
  end

  class OverriddenInitializerTest < ActiveSupport::TestCase
    test "merges in the initializers from the parent in the right order" do
      $arr = []
      OverriddenInitializer.new.run_initializers
      assert_equal [1, 2, 3, 4], $arr
    end
  end

  class CollectionTest < ActiveSupport::TestCase
    test "delegates missing to collection array" do
      initializable = Class.new do
        include Rails::Initializable
      end

      Array.public_instance_methods.each do |method_name|
        assert(
          initializable.initializers.respond_to?(method_name),
          "Expected Initializable::Collection to respond to #{method_name}, but does not.",
        )
      end
    end

    test "concat" do
      one = collection(:a, :b)
      two = collection(:c, :d)
      initializers = one.initializers.concat(two.initializers)
      initializer_names = initializers.tsort_each.map(&:name)

      assert_equal [:a, :b, :c, :d], initializer_names
    end

    test "push" do
      one = collection(:a, :b, :c)
      two = collection(:d)
      initializers = one.initializers.push(two.initializers.first)
      initializer_names = initializers.tsort_each.map(&:name)

      assert_equal [:a, :b, :c, :d], initializer_names
    end

    test "append" do
      one = collection(:a)
      two = collection(:b, :c)
      initializers = one.initializers.append(two.initializers.first)
      initializer_names = initializers.tsort_each.map(&:name)

      assert_equal [:a, :b], initializer_names
    end

    test "<<" do
      one = collection(:a, :b)
      two = collection(:c)
      initializers = (one.initializers << two.initializers.first)
      initializer_names = initializers.tsort_each.map(&:name)

      assert_equal [:a, :b, :c], initializer_names
    end

    private
      def collection(*names)
        Class.new do
          include Rails::Initializable
          names.each { |name| initializer(name) { } }
        end
      end
  end
end
