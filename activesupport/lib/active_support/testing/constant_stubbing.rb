# frozen_string_literal: true

module ActiveSupport
  module Testing
    module ConstantStubbing
      # Changes the value of a constant for the duration of a block. Example:
      #
      #   # World::List::Import::LARGE_IMPORT_THRESHOLD = 5000
      #   stub_const(World::List::Import, :LARGE_IMPORT_THRESHOLD, 1) do
      #     assert_equal 1, World::List::Import::LARGE_IMPORT_THRESHOLD
      #   end
      #
      #   assert_equal 5000, World::List::Import::LARGE_IMPORT_THRESHOLD
      #
      # Using this method rather than forcing <tt>World::List::Import::LARGE_IMPORT_THRESHOLD = 5000</tt> prevents
      # warnings from being thrown, and ensures that the old value is returned after the test has completed.
      #
      # If the constant doesn't already exists, but you need it set for the duration of the block
      # you can do so by passing `exists: false`.
      #
      #   stub_const(object, :SOME_CONST, 1, exists: false) do
      #     assert_equal 1, SOME_CONST
      #   end
      #
      # Note: Stubbing a const will stub it across all threads. So if you have concurrent threads
      # (like separate test suites running in parallel) that all depend on the same constant, it's possible
      # divergent stubbing will trample on each other.
      def stub_const(mod, constant, new_value, exists: true)
        if exists
          begin
            old_value = mod.const_get(constant, false)
            mod.send(:remove_const, constant)
            mod.const_set(constant, new_value)
            yield
          ensure
            mod.send(:remove_const, constant)
            mod.const_set(constant, old_value)
          end
        else
          if mod.const_defined?(constant)
            raise NameError, "already defined constant #{constant} in #{mod.name}"
          end

          begin
            mod.const_set(constant, new_value)
            yield
          ensure
            mod.send(:remove_const, constant)
          end
        end
      end
    end
  end
end
