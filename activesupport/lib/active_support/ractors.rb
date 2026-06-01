# frozen_string_literal: true

module ActiveSupport
  # Shims for +Ractor+ shareability methods so framework code can call them
  # unconditionally regardless of the Ruby version.
  module Ractors # :nodoc:
    class << self
      if defined?(Ractor) && Ractor.respond_to?(:make_shareable)
        # Makes +obj+ Ractor-shareable by delegating to +Ractor.make_shareable+.
        #
        # The +copy:+ option is forwarded unchanged. On Ruby versions without
        # +Ractor.make_shareable+, this shim returns +obj+ unchanged.
        def make_shareable(...)
          Ractor.make_shareable(...)
        end
      else
        def make_shareable(obj, copy: false)
          obj
        end
      end

      if defined?(Ractor) && Ractor.respond_to?(:shareable?)
        # Returns whether +obj+ is Ractor-shareable by delegating to
        # +Ractor.shareable?+.
        #
        # On Ruby versions without +Ractor.shareable?+, this shim returns +obj+
        # unchanged.
        def shareable?(obj)
          Ractor.shareable?(obj)
        end
      else
        def shareable?(obj)
          obj
        end
      end

      if defined?(Ractor) && Ractor.respond_to?(:shareable_proc)
        # Returns a Ractor-shareable proc by delegating to +Ractor.shareable_proc+.
        #
        # The optional +self:+ value is forwarded as the proc's receiver. On Ruby
        # versions without +Ractor.shareable_proc+, this shim returns the block
        # unchanged.
        def shareable_proc(...)
          Ractor.shareable_proc(...)
        end
      else
        def shareable_proc(self: nil, &block)
          block
        end
      end

      if defined?(Ractor) && Ractor.respond_to?(:shareable_lambda)
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
        def shareable_lambda(&block)
          block
        end
      end
    end
  end
end
