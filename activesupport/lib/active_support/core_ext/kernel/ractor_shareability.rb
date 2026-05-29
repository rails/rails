# frozen_string_literal: true

# Shims for +Ractor+ shareability methods so framework code can call them
# unconditionally regardless of the Ruby version.
#
# On Ruby 4.0 and above, these methods delegate to the corresponding +Ractor+ methods. On older Ruby versions, these
# methods are no-ops that return their argument.
#
#   ractor_make_shareable(obj)        # => Ractor.make_shareable(obj)        or obj
#   ractor_shareable?(obj)            # => Ractor.shareable?(obj)            or obj
#   ractor_shareable_proc   { ... }   # => Ractor.shareable_proc   { ... }   or the block
#   ractor_shareable_lambda { ... }   # => Ractor.shareable_lambda { ... }   or the block
module Kernel
  private
    if RUBY_VERSION >= "4.0" && defined?(Ractor)
      # Makes +obj+ Ractor-shareable by delegating to +Ractor.make_shareable+.
      #
      # The +copy:+ option is forwarded unchanged. This method is
      # a no-op on Ruby version earlier than 4.0
      def ractor_make_shareable(obj, copy: false)
        Ractor.make_shareable(obj, copy: copy)
      end

      # Returns whether +obj+ is Ractor-shareable by delegating to
      # +Ractor.shareable?+.
      #
      # This method is a no-op on Ruby version earlier than 4.0
      def ractor_shareable?(obj)
        Ractor.shareable?(obj)
      end

      # Returns a Ractor-shareable proc by delegating to +Ractor.shareable_proc+.
      #
      # The optional +self:+ value is forwarded as the proc's receiver. This method is
      # a no-op on Ruby version earlier than 4.0
      def ractor_shareable_proc(self: nil, &block)
        Ractor.shareable_proc(self: { self: }[:self], &block)
      end

      # Returns a Ractor-shareable lambda by delegating to
      # +Ractor.shareable_lambda+.
      #
      # The optional +self:+ value is forwarded as the lambda's receiver. This method is
      # a no-op on Ruby version earlier than 4.0
      def ractor_shareable_lambda(self: nil, &block)
        Ractor.shareable_lambda(self: { self: }[:self], &block)
      end
    else
      def ractor_make_shareable(obj, copy: false)
        obj
      end

      def ractor_shareable?(obj, copy: false)
        obj
      end

      def ractor_shareable_proc(self: nil, &block)
        block
      end

      def ractor_shareable_lambda(self: nil, &block)
        block
      end
    end
end
