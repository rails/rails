module ActiveSupport
  module Testing
    module MethodCallAssertions # :nodoc:
      private
        def assert_called(object, method_name, message = nil, times: 1)
          times_called = 0

          object.stub(method_name, ->(*args) { times_called += 1 }) { yield }

          error = "Expected #{method_name} to be called #{times} times, " \
            "but was called #{times_called} times"
          error = "#{message}.\n#{error}" if message
          assert_equal times, times_called, error
        end

        def assert_called_with(object, method_name, args = [], returns: nil, use_distinct_returns: false)
          mock = Minitest::Mock.new

          if args.all? { |arg| arg.is_a?(Array) }
            if use_distinct_returns
              if returns.nil? || !returns.is_a?(Array) || returns.length != args.length
                raise(ArgumentError, 'returns must be an array and match the number of arguments')
              end
              args.each_with_index { |arg, i| mock.expect(:call, returns[i], arg) }
            else
              args.each { |arg| mock.expect(:call, returns, arg) }
            end
          else
            mock.expect(:call, returns, args)
          end

          object.stub(method_name, mock) { yield }

          mock.verify
        end

        def assert_not_called(object, method_name, message = nil, &block)
          assert_called(object, method_name, message, times: 0, &block)
        end
    end
  end
end
