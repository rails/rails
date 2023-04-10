# frozen_string_literal: true

require "minitest/mock"

module ActiveSupport
  module Testing
    module MethodCallAssertions # :nodoc:
      private
        def assert_called(object, method_name, message = nil, times: 1, returns: nil, &block)
          times_called = 0

          object.stub(method_name, proc { times_called += 1; returns }, &block)

          error = "Expected #{method_name} to be called #{times} times, " \
            "but was called #{times_called} times"
          error = "#{message}.\n#{error}" if message
          assert_equal times, times_called, error
        end

        def assert_called_with(object, method_name, args, returns: false, **kwargs, &block)
          mock = Minitest::Mock.new
          expect_called_with(mock, args, returns: returns, **kwargs)

          object.stub(method_name, mock, &block)

          assert_mock(mock)
        end

        def assert_not_called(object, method_name, message = nil, &block)
          assert_called(object, method_name, message, times: 0, &block)
        end

        #--
        # This method is a temporary wrapper for mock.expect as part of
        # the Minitest 5.16 / Ruby 3.0 kwargs transition. It can go away
        # when we drop support for Ruby 2.7.
        if Minitest::Mock.instance_method(:expect).parameters.map(&:first).include?(:keyrest)
          def expect_called_with(mock, args, returns: false, **kwargs)
            mock.expect(:call, returns, args, **kwargs)
          end
        else
          def expect_called_with(mock, args, returns: false, **kwargs)
            if !kwargs.empty?
              mock.expect(:call, returns, [*args, kwargs])
            else
              mock.expect(:call, returns, args)
            end
          end
        end

        def assert_called_on_instance_of(klass, method_name, message = nil, times: 1, returns: nil)
          times_called = 0
          klass.define_method("stubbed_#{method_name}") do |*|
            times_called += 1

            returns
          end

          klass.alias_method "original_#{method_name}", method_name
          klass.alias_method method_name, "stubbed_#{method_name}"

          yield

          error = "Expected #{method_name} to be called #{times} times, but was called #{times_called} times"
          error = "#{message}.\n#{error}" if message

          assert_equal times, times_called, error
        ensure
          klass.alias_method method_name, "original_#{method_name}"
          klass.undef_method "original_#{method_name}"
          klass.undef_method "stubbed_#{method_name}"
        end

        def assert_not_called_on_instance_of(klass, method_name, message = nil, &block)
          assert_called_on_instance_of(klass, method_name, message, times: 0, &block)
        end

        def stub_any_instance(klass, instance: klass.new)
          klass.stub(:new, instance) { yield instance }
        end
    end
  end
end
