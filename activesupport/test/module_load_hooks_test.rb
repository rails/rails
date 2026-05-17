# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/module/remove_method"

class ModuleLoadHooksTest < ActiveSupport::TestCase
  class TestLoader
    class TestClass
      class << self
        attr_accessor :config
      end
      self.config = false
    end

    def initialize
      @hooks = {}
    end

    def on_load(name, &block)
      @hooks[self.class.const_get(name.to_s)] = block
    end

    def execute
      @hooks.each do |klass, block|
        block.call(klass)
      end
    end
  end

  def test_no_autoloader
    ActiveSupport.autoloader = nil
    error = assert_raises(NotImplementedError) do
      ActiveSupport.on_module_load(:TestClass) { self.config = true }
    end

    assert_equal("ActiveSupport.autoloader must be set.", error.message)
  end

  def test_autoloader
    autoloader = TestLoader.new
    ActiveSupport.autoloader = autoloader
    ActiveSupport.on_module_load(:TestClass) { self.config = true }
    autoloader.execute

    assert TestLoader::TestClass.config
  ensure
    TestLoader::TestClass.config = false
    ActiveSupport.autoloader = nil
  end
end
