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

  class Basic < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    test "initializers run" do
      Foo.initializers.run
      assert_equal 1, Foo.foo
    end

    test "initializers are inherited" do
      Bar.initializers.run
      assert_equal [1, 1], [Bar.foo, Bar.bar]
    end

    test "initializers only get run once" do
      Foo.initializers.run
      Foo.initializers.run
      assert_equal 1, Foo.foo
    end

    test "running initializers on children does not effect the parent" do
      Bar.initializers.run
      assert_nil Foo.foo
      assert_nil Foo.bar
    end

    test "inherited initializers are the same objects" do
      assert Foo.initializers[:foo].eql?(Bar.initializers[:foo])
    end

    test "initializing with modules" do
      Word.initializers.run
      assert_equal "bird", $word
    end
  end
end