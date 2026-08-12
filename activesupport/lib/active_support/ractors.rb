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

      # Attempt to make a lambda shareable, bound to +receiver+ as its +self+.
      # If successful, a shareable lambda is returned. If a Ractor::IsolationError
      # is raised, the outcome will depend on the user's application configuration:
      #
      # :raise - The error is raised
      # :warn  - A deprecation warning is triggered and the original unshareable lambda is returned.
      def try_shareable_lambda(receiver, &block)
        return block unless unshareable_proc_action

        shareable_lambda(self: receiver, &block)
      rescue Ractor::IsolationError
        case unshareable_proc_action
        when :raise
          raise
        when :warn
          ActiveSupport.deprecator.warn(<<~MSG)
            Rails attempted to make a lambda from your application Ractor shareable but a Ractor
            Isolation error was raised. The lambda being returned is not Ractor safe and a runtime
            error may occur anytime during the request lifecycle.

            #{block.inspect}
          MSG

          block
        end
      end

      # Attempt to make an object shareable. If successful, a shareable object is returned.
      # If a Ractor::IsolationError is raised, the outcome will depend on how
      # the user's application configuration:
      #
      # :raise - The error is raised
      # :warn  - A deprecation warning is triggered and the original unshareable object is returned.
      def try_make_shareable(obj, **)
        return obj unless unshareable_proc_action

        make_shareable(obj, **)
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

      if RUBY_VERSION >= "4.0"
        def on_main(obj = nil, &block)
          if Ractor.main?
            obj.instance_eval(&block)
          else
            require "ractor/dispatch"
            shareable_block = Ractor.shareable_proc(&block)
            Ractor::Dispatch.main.run { obj.instance_eval(&shareable_block) }
          end
        end

        def main?
          Ractor.main?
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
        def main?
          Ractor.current == Ractor.main
        end

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

    # Returns the value stored under +key+ in the current Ractor's local
    # storage. Returns +nil+ when nothing has been stored under +key+ yet.
    #
    # Each Ractor has an isolated local storage, so values set in one Ractor
    # are not visible to any other.
    def self.[](key)
      Ractor.current[key]
    end

    # Stores +value+ under +key+ in the current Ractor's local storage.
    # The value is only visible to the current Ractor, and other
    # Ractors have their own independent storage.
    def self.[]=(key, value)
      Ractor.current[key] = value
    end

    if Ractor.respond_to?(:store_if_absent)
      # Returns the value stored under +key+ in the current Ractor's local
      # storage, running +block+ to compute and store it on first access, by
      # delegating to +Ractor.store_if_absent+. Concurrent threads in the
      # same Ractor initialize the value only once.
      def self.store_if_absent(key, &block)
        Ractor.store_if_absent(key, &block)
      end
    else
      @local_storage_lock = Mutex.new

      # Same contract as +Ractor.store_if_absent+ (Ruby 3.4) on top of the
      # Ractor-local storage that predates it: the value is initialized at
      # most once even when the Ractor's threads race, with an unsynchronized
      # fast path for the common hit.
      def self.store_if_absent(key, &block)
        Ractor.current[key] || @local_storage_lock.synchronize { Ractor.current[key] ||= block.call }
      end
    end
  end
end
