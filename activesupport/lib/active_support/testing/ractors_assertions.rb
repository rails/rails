# frozen_string_literal: true

module ActiveSupport
  module Testing
    module RactorsAssertions # :nodoc: all
      private
        if RUBY_VERSION >= "4.0"
          def on_ractor(*args, &block)
            block = Ractor.shareable_proc(&block)

            port = Ractor::Port.new

            Ractor.new(port, block, args) do |port, block, args|
              port.send block.call(*args)
            end.join

            port.receive
          end

          def assert_ractor_make_shareable(obj)
            assert_nothing_raised { Ractor.make_shareable(obj) }
          end

          def assert_ractor_shareable(obj)
            assert Ractor.shareable?(obj), "Expected #{obj.inspect} to be shareable, but it is not."
          end

          def assert_not_ractor_shareable(obj)
            assert_not Ractor.shareable?(obj), "Expected #{obj.inspect} to not be shareable, but it is."
          end
        else
          def on_ractor(*args)
            yield(*args)
          end

          def assert_ractor_make_shareable(obj)
            assert true
          end

          def assert_ractor_shareable(obj)
            assert true
          end

          def assert_not_ractor_shareable(obj)
            assert true
          end
        end
    end
  end
end
