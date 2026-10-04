# frozen_string_literal: true

require "action_dispatch/system_testing/test_adapter"

module ActionDispatch
  module SystemTesting
    # Resolves symbolic names used by `ServerSystemTestCase.testing_with`.
    module TestAdapters
      class AdapterNotFoundError < StandardError
      end

      class << self
        # Registers an adapter class under a symbolic name.
        #
        #     TestAdapters.register(:my_browser, MyBrowserAdapter)
        def register(name, adapter)
          if !name.is_a?(String) && !name.is_a?(Symbol)
            raise ArgumentError, "system test adapter name must be a String or Symbol"
          end

          if adapter.is_a?(Class) && adapter < TestAdapter
            adapters[name.to_sym] = adapter
          else
            raise ArgumentError, "system test adapter must inherit from ActionDispatch::SystemTesting::TestAdapter"
          end
        end

        # Returns the adapter class registered for +name+.
        def lookup(name)
          if !name.is_a?(String) && !name.is_a?(Symbol)
            raise ArgumentError, "system test adapter name must be a String or Symbol"
          end

          adapters[name.to_sym] or raise AdapterNotFoundError, "system test adapter not found: #{name.inspect}"
        end

        private
          def adapters
            @adapters ||= {}
          end
      end
    end
  end
end
