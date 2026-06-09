# frozen_string_literal: true

module ActiveSupport
  # Shims for +Ractor+ shareability methods so framework code can call them
  # unconditionally regardless of the Ruby version.
  module Ractors # :nodoc:
    class << self
      if defined?(Ractor) && RUBY_VERSION >= "4.0"
        gem "ractor-dispatch"
        require "ractor/dispatch"

        def on_main(obj = nil, &block)
          if Ractor.main?
            obj.instance_eval(&block)
          else
            shareable_block = shareable_proc(&block)
            Ractor::Dispatch.main.run { obj.instance_eval(&shareable_block) }
          end
        end

        # Makes +obj+ Ractor-shareable by delegating to +Ractor.make_shareable+.
        #
        # The +copy:+ option is forwarded unchanged. On Ruby versions without
        # +Ractor.make_shareable+, this shim returns +obj+ unchanged.
        def make_shareable(...)
          Ractor.make_shareable(...)
        end

        # Returns whether +obj+ is Ractor-shareable by delegating to
        # +Ractor.shareable?+.
        #
        # On Ruby versions without +Ractor.shareable?+, this shim returns +obj+
        # unchanged.
        def shareable?(obj)
          Ractor.shareable?(obj)
        end

        # Returns a Ractor-shareable proc by delegating to +Ractor.shareable_proc+.
        #
        # The optional +self:+ value is forwarded as the proc's receiver. On Ruby
        # versions without +Ractor.shareable_proc+, this shim returns the block
        # unchanged.
        def shareable_proc(...)
          Ractor.shareable_proc(...)
        end

        # Returns a Ractor-shareable lambda by delegating to
        # +Ractor.shareable_lambda+.
        #
        # The optional +self:+ value is forwarded as the lambda's receiver. On Ruby
        # versions without +Ractor.shareable_lambda+, this shim returns the block
        # unchanged.
        def shareable_lambda(...)
          Ractor.shareable_lambda(...)
        end
      else
        def on_main(obj = nil, &block)
          obj.instance_eval(&block)
        end

        def make_shareable(obj, copy: false)
          obj
        end

        def shareable?(obj)
          obj
        end

        def shareable_proc(self: nil, &block)
          block
        end

        def shareable_lambda(self: nil, &block)
          block
        end
      end
    end
  end
end
