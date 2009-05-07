require 'abstract_unit'
require 'active_support/dependency_module'

class DependencyModuleTest < Test::Unit::TestCase
  module Baz
    extend ActiveSupport::DependencyModule

    module ClassMethods
      def baz
        "baz"
      end

      def setup=(value)
        @@setup = value
      end

      def setup
        @@setup
      end
    end

    setup do
      self.setup = true
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

  def test_setup_block_is_ran
    @klass.send(:include, Baz)
    assert_equal true, @klass.setup
  end

  def test_modules_dependencies_are_met
    @klass.send(:include, Bar)
    assert_equal "bar", @klass.new.bar
    assert_equal "bar+baz", @klass.new.baz
    assert_equal "baz", @klass.baz
    assert_equal [DependencyModuleTest::Bar, DependencyModuleTest::Baz], @klass.included_modules[0..1]
  end
end
