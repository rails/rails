require "rbconfig"

module ActiveSupport
  class Deprecation
    module Reporting
      # Whether to print a message (silent mode)
      attr_accessor :silenced
      # Name of gem where method is deprecated
      attr_accessor :gem_name

      # Outputs a deprecation warning to the output configured by
      # <tt>ActiveSupport::Deprecation.behavior</tt>.
      #
      #   ActiveSupport::Deprecation.warn('something broke!')
      #   # => "DEPRECATION WARNING: something broke! (called from your_code.rb:1)"
      def warn(message = nil, callstack = nil)
        return if silenced

        callstack ||= caller_locations(2)
        deprecation_message(callstack, message).tap do |m|
          behavior.each { |b| b.call(m, callstack) }
        end
      end

      # Silence deprecation warnings within the block.
      #
      #   ActiveSupport::Deprecation.warn('something broke!')
      #   # => "DEPRECATION WARNING: something broke! (called from your_code.rb:1)"
      #
      #   ActiveSupport::Deprecation.silence do
      #     ActiveSupport::Deprecation.warn('something broke!')
      #   end
      #   # => nil
      def silence
        old_silenced, @silenced = @silenced, true
        yield
      ensure
        @silenced = old_silenced
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
        #   ActiveSupport::Deprecation.deprecated_method_warning(:method_name)
        #   # => "method_name is deprecated and will be removed from Rails #{deprecation_horizon}"
        #   ActiveSupport::Deprecation.deprecated_method_warning(:method_name, :another_method)
        #   # => "method_name is deprecated and will be removed from Rails #{deprecation_horizon} (use another_method instead)"
        #   ActiveSupport::Deprecation.deprecated_method_warning(:method_name, "Optional message")
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
          return _extract_callstack(callstack) if callstack.first.is_a? String

          offending_line = callstack.find { |frame|
            frame.absolute_path && !ignored_callstack(frame.absolute_path)
          } || callstack.first

          [offending_line.path, offending_line.lineno, offending_line.label]
        end

        def _extract_callstack(callstack)
          warn "Please pass `caller_locations` to the deprecation API" if $VERBOSE
          offending_line = callstack.find { |line| !ignored_callstack(line) } || callstack.first

          if offending_line
            if md = offending_line.match(/^(.+?):(\d+)(?::in `(.*?)')?/)
              md.captures
            else
              offending_line
            end
          end
        end

        RAILS_GEM_ROOT = File.expand_path("../../../../..", __FILE__) + "/"

        def ignored_callstack(path)
          path.start_with?(RAILS_GEM_ROOT) || path.start_with?(RbConfig::CONFIG["rubylibdir"])
        end
    end
  end
end
