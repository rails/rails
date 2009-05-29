require 'abstract_unit'
require 'active_support/concern'

class ConcernTest < Test::Unit::TestCase
  module Baz
    extend ActiveSupport::Concern

    module ClassMethods
      def baz
        "baz"
      end

      def included_ran=(value)
        @@included_ran = value
      end

      def included_ran
        @@included_ran
      end
    end

    module InstanceMethods
    end

    included do
      self.included_ran = true
    end

    def baz
      "baz"
    end
  end

  module Bar
    extend ActiveSupport::Concern

    include Baz

    def bar
      "bar"
    end

    def baz
      "bar+" + super
    end
  end

  module Foo
    extend ActiveSupport::Concern

    include Bar, Baz
  end

  def setup
    @klass = Class.new
  end

  def test_module_is_included_normally
    @klass.send(:include, Baz)
    assert_equal "baz", @klass.new.baz
    assert @klass.included_modules.include?(ConcernTest::Baz)

    @klass.send(:include, Baz)
    assert_equal "baz", @klass.new.baz
    assert @klass.included_modules.include?(ConcernTest::Baz)
  end

  def test_class_methods_are_extended
    @klass.send(:include, Baz)
    assert_equal "baz", @klass.baz
    assert_equal ConcernTest::Baz::ClassMethods, (class << @klass; self.included_modules; end)[0]
  end

  def test_instance_methods_are_included
    @klass.send(:include, Baz)
    assert_equal "baz", @klass.new.baz
    assert @klass.included_modules.include?(ConcernTest::Baz::InstanceMethods)
  end

  def test_included_block_is_ran
    @klass.send(:include, Baz)
    assert_equal true, @klass.included_ran
  end

  def test_modules_dependencies_are_met
    @klass.send(:include, Bar)
    assert_equal "bar", @klass.new.bar
    assert_equal "bar+baz", @klass.new.baz
    assert_equal "baz", @klass.baz
    assert @klass.included_modules.include?(ConcernTest::Bar)
  end

  def test_dependencies_with_multiple_modules
    @klass.send(:include, Foo)
    assert_equal [ConcernTest::Foo, ConcernTest::Bar, ConcernTest::Baz::InstanceMethods, ConcernTest::Baz], @klass.included_modules[0..3]
  end
end
