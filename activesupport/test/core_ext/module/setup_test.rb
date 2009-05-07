require 'abstract_unit'
require 'active_support/core/time'
require 'active_support/core_ext/module/setup'

class SetupTest < Test::Unit::TestCase
  module Baz
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
    @klass.use(Baz)
    assert_equal "baz", @klass.new.baz
    assert_equal SetupTest::Baz, @klass.included_modules[0]

    @klass.use(Baz)
    assert_equal "baz", @klass.new.baz
    assert_equal SetupTest::Baz, @klass.included_modules[0]
  end

  def test_class_methods_are_extended
    @klass.use(Baz)
    assert_equal "baz", @klass.baz
    assert_equal SetupTest::Baz::ClassMethods, (class << @klass; self.included_modules; end)[0]
  end

  def test_setup_block_is_ran
    @klass.use(Baz)
    assert_equal true, @klass.setup
  end

  def test_modules_dependencies_are_met
    @klass.use(Bar)
    assert_equal "bar", @klass.new.bar
    assert_equal "bar+baz", @klass.new.baz
    assert_equal "baz", @klass.baz
    assert_equal [SetupTest::Bar, SetupTest::Baz], @klass.included_modules[0..1]
  end
end
