# frozen_string_literal: true

require "rbconfig"

module ActiveSupport
  class Deprecation
    module Reporting
      # Whether to print a message (silent mode)
      attr_writer :silenced
      # Name of gem where method is deprecated
      attr_accessor :gem_name

      # Outputs a deprecation warning to the output configured by
      # ActiveSupport::Deprecation#behavior.
      #
      #   ActiveSupport::Deprecation.new.warn('something broke!')
      #   # => "DEPRECATION WARNING: something broke! (called from your_code.rb:1)"
      def warn(message = nil, callstack = nil)
        return if silenced

        callstack ||= caller_locations(2)
        deprecation_message(callstack, message).tap do |full_message|
          if deprecation_disallowed?(message)
            disallowed_behavior.each { |b| b.call(full_message, callstack, self) }
          else
            behavior.each { |b| b.call(full_message, callstack, self) }
          end
        end
      end

      # Silence deprecation warnings within the block.
      #
      #   deprecator = ActiveSupport::Deprecation.new
      #   deprecator.warn('something broke!')
      #   # => "DEPRECATION WARNING: something broke! (called from your_code.rb:1)"
      #
      #   deprecator.silence do
      #     deprecator.warn('something broke!')
      #   end
      #   # => nil
      def silence(&block)
        begin_silence
        block.call
      ensure
        end_silence
      end

      def begin_silence # :nodoc:
        @silence_counter.value += 1
      end

      def end_silence # :nodoc:
        @silence_counter.value -= 1
      end

      def silenced
        @silenced || @silence_counter.value.nonzero?
      end

      # Allow previously disallowed deprecation warnings within the block.
      # <tt>allowed_warnings</tt> can be an array containing strings, symbols, or regular
      # expressions. (Symbols are treated as strings). These are compared against
      # the text of deprecation warning messages generated within the block.
      # Matching warnings will be exempt from the rules set by
      # ActiveSupport::Deprecation#disallowed_warnings.
      #
      # The optional <tt>if:</tt> argument accepts a truthy/falsy value or an object that
      # responds to <tt>.call</tt>. If truthy, then matching warnings will be allowed.
      # If falsey then the method yields to the block without allowing the warning.
      #
      #   deprecator = ActiveSupport::Deprecation.new
      #   deprecator.disallowed_behavior = :raise
      #   deprecator.disallowed_warnings = [
      #     "something broke"
      #   ]
      #
      #   deprecator.warn('something broke!')
      #   # => ActiveSupport::DeprecationException
      #
      #   deprecator.allow ['something broke'] do
      #     deprecator.warn('something broke!')
      #   end
      #   # => nil
      #
      #   deprecator.allow ['something broke'], if: Rails.env.production? do
      #     deprecator.warn('something broke!')
      #   end
      #   # => ActiveSupport::DeprecationException for dev/test, nil for production
      def allow(allowed_warnings = :all, if: true, &block)
        conditional = binding.local_variable_get(:if)
        conditional = conditional.call if conditional.respond_to?(:call)
        if conditional
          @explicitly_allowed_warnings.bind(allowed_warnings, &block)
        else
          yield
        end
      end

      def deprecation_warning(deprecated_method_name, message = nil, caller_backtrace = nil)
        caller_backtrace ||= caller_locations(2)
        deprecated_method_warning(deprecated_method_name, message).tap do |msg|
          warn(msg, caller_backtrace)
        end
      end

      private
        # Outputs a deprecation warning message
        #
        #   deprecated_method_warning(:method_name)
        #   # => "method_name is deprecated and will be removed from Rails #{deprecation_horizon}"
        #   deprecated_method_warning(:method_name, :another_method)
        #   # => "method_name is deprecated and will be removed from Rails #{deprecation_horizon} (use another_method instead)"
        #   deprecated_method_warning(:method_name, "Optional message")
        #   # => "method_name is deprecated and will be removed from Rails #{deprecation_horizon} (Optional message)"
        def deprecated_method_warning(method_name, message = nil)
          warning = "#{method_name} is deprecated and will be removed from #{gem_name} #{deprecation_horizon}"
          case message
          when Symbol then "#{warning} (use #{message} instead)"
          when String then "#{warning} (#{message})"
          else warning
          end
        end

        def deprecation_message(callstack, message = nil)
          message ||= "You are using deprecated behavior which will be removed from the next major or minor release."
          "DEPRECATION WARNING: #{message} #{deprecation_caller_message(callstack)}"
        end

        def deprecation_caller_message(callstack)
          file, line, method = extract_callstack(callstack)
          if file
            if line && method
              "(called from #{method} at #{file}:#{line})"
            else
              "(called from #{file}:#{line})"
            end
          end
        end

        def extract_callstack(callstack)
          return [] if callstack.empty?

          offending_line = callstack.find { |frame|
            # Code generated with `eval` doesn't have an `absolute_path`, e.g. templates.
            path = frame.absolute_path || frame.path
            path && !ignored_callstack?(path)
          } || callstack.first

          [offending_line.path, offending_line.lineno, offending_line.label]
        end

        RAILS_GEM_ROOT = File.expand_path("../../../..", __dir__) + "/" # :nodoc:
        LIB_DIR = RbConfig::CONFIG["libdir"] # :nodoc:

        def ignored_callstack?(path)
          path.start_with?(RAILS_GEM_ROOT, LIB_DIR) || path.include?("<internal:")
        end
    end
  end
end
