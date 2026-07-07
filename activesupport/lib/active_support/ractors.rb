# frozen_string_literal: true

require "active_support/dependencies/autoload"

module ActiveSupport
  # Shims for +Ractor+ shareability methods so framework code can call them
  # unconditionally regardless of the Ruby version.
  module Ractors # :nodoc:
    extend ActiveSupport::Autoload
    autoload :Logger

    class << self
      attr_accessor :unshareable_proc_action

      # Attempt to make a proc shareable. If successful, a shareable proc is returned.
      # If a Ractor::IsolationError is raised, the outcome will depend on how
      # the user's application configuration:
      #
      # :raise - The error is raised
      # :warn  - A deprecation warning is triggered and the original unshareable proc is returned.
      def try_shareable_proc(proc = nil, &block)
        proc ||= block
        return proc unless unshareable_proc_action

        shareable_proc(&proc)
      rescue Ractor::IsolationError
        case unshareable_proc_action
        when :raise
          raise
        when :warn
          ActiveSupport.deprecator.warn(<<~MSG)
            Rails attempted to make a Proc from your application Ractor shareable but a Ractor
            Isolation error was raised. The proc being returned is not Ractor safe and a runtime
            error may occur anytime during the request lifecycle.

            #{proc.inspect}
          MSG

          proc
        end
      end

      # Attempt to make an object shareable. If successful, a shareable object is returned.
      # If a Ractor::IsolationError is raised, the outcome will depend on how
      # the user's application configuration:
      #
      # :raise - The error is raised
      # :warn  - A deprecation warning is triggered and the original unshareable object is returned.
      def try_make_shareable(obj)
        return obj unless unshareable_proc_action

        make_shareable(obj)
      rescue Ractor::IsolationError
        case unshareable_proc_action
        when :raise
          raise
        when :warn
          ActiveSupport.deprecator.warn(<<~MSG)
            Rails attempted to make an object from your application Ractor shareable but a Ractor
            Isolation error was raised. The object being returned is not Ractor safe and a runtime
            error may occur anytime during the request lifecycle.

            #{obj.inspect}
          MSG

          obj
        end
      end

      # Attempts to make +collection+ Ractor-shareable, first converting any
      # +Proc+ elements (for an +Array+) or values (for a +Hash+) into shareable
      # procs.
      #
      # Like the other +try_+ helpers, this hinges on +unshareable_proc_action+
      # and is a no-op when it is not set. It is used to freeze configuration
      # collections that may hold application-defined procs, which
      # +make_shareable+ cannot deeply freeze on its own.
      def make_procs_shareable(collection)
        return collection unless unshareable_proc_action
        return collection if shareable?(collection)

        case collection
        when Array
          collection.map! { |element| make_element_shareable(element) }
        when Hash
          collection.transform_values! { |value| make_element_shareable(value) }
        end

        try_make_shareable(collection)
      end

      # Attempts to make a single +element+ Ractor-shareable. +Proc+ elements are
      # converted into shareable procs, everything else is delegated to
      # +try_make_shareable+.
      def make_element_shareable(element)
        if element.is_a?(Proc)
          try_shareable_proc(element)
        else
          try_make_shareable(element)
        end
      end
      private :make_element_shareable

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
