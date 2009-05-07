require 'abstract_unit'
require 'active_support/dependency_module'

class DependencyModuleTest < Test::Unit::TestCase
  module Baz
    extend ActiveSupport::DependencyModule

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

    included do
      self.included_ran = true
    end

    def baz
      "baz"
    end
  end

  module Bar
    extend ActiveSupport::DependencyModule

    depends_on Baz

    def bar
      "bar"
    end

    def baz
      "bar+" + super
    end
  end

  def setup
    @klass = Class.new
  end

  def test_module_is_included_normally
    @klass.send(:include, Baz)
    assert_equal "baz", @klass.new.baz
    assert_equal DependencyModuleTest::Baz, @klass.included_modules[0]

    @klass.send(:include, Baz)
    assert_equal "baz", @klass.new.baz
    assert_equal DependencyModuleTest::Baz, @klass.included_modules[0]
  end

  def test_class_methods_are_extended
    @klass.send(:include, Baz)
    assert_equal "baz", @klass.baz
    assert_equal DependencyModuleTest::Baz::ClassMethods, (class << @klass; self.included_modules; end)[0]
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
    assert_equal [DependencyModuleTest::Bar, DependencyModuleTest::Baz], @klass.included_modules[0..1]
  end
end
