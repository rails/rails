# frozen_string_literal: true

module ActiveSupport
  # Shims for +Ractor+ shareability methods so framework code can call them
  # unconditionally regardless of the Ruby version.
  module Ractors # :nodoc:
    class << self
      attr_accessor :unshareable_proc_action

      # Attempts to return a Ractor-shareable copy of +proc+ when configured.
      #
      # +unshareable_proc_action+ controls what happens if the proc can't be
      # made shareable:
      #
      # * +:raise+ raises the original +Ractor::IsolationError+
      # * +:warn+ emits a deprecation warning and returns the original proc
      # * +nil+ returns the original proc without attempting to make it shareable
      def shareable_proc_attempt(proc = nil, &block)
        proc ||= block
        return proc unless unshareable_proc_action

        shareable_proc(&proc)
      rescue Ractor::IsolationError
        case unshareable_proc_action
        when :raise
          raise
        when :warn
          ActiveSupport.deprecator.warn(<<~MSG.squish)
            Rails attempted to make a Proc from your application Ractor shareable but a Ractor
            isolation error was raised. The proc being returned is not Ractor safe and a runtime
            error may occur anytime during the request lifecycle.
          MSG

          proc
        end
      end

      if defined?(Ractor) && RUBY_VERSION >= "4.0"
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
