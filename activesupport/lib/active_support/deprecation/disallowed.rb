# frozen_string_literal: true

module ActiveSupport
  class Deprecation
    module Disallowed
      # Sets the criteria used to identify deprecation messages which should be
      # disallowed. Can be an array containing strings, symbols, or regular
      # expressions. (Symbols are treated as strings). These are compared against
      # the text of the generated deprecation warning.
      #
      # Additionally the scalar symbol +:all+ may be used to treat all
      # deprecations as disallowed.
      #
      # Deprecations matching a substring or regular expression will be handled
      # using the configured ActiveSupport::Deprecation#disallowed_behavior
      # rather than ActiveSupport::Deprecation#behavior.
      attr_writer :disallowed_warnings

      # Returns the configured criteria used to identify deprecation messages
      # which should be treated as disallowed. Defaults to
      # +ActiveSupport::Deprecation.disallowed_warnings+.
      def disallowed_warnings
        @disallowed_warnings || self.class.disallowed_warnings
      end

      # Allow previously disallowed deprecation warnings within the block.
      # <tt>allowed_warnings</tt> can be an array containing strings, symbols, or regular
      # expressions. (Symbols are treated as strings). These are compared against
      # the text of deprecation warning messages generated within the block.
      # Matching warnings will be exempt from the rules set by
      # +ActiveSupport::Deprecation.disallowed_warnings+
      #
      # The optional <tt>if:</tt> argument accepts a truthy/falsy value or an object that
      # responds to <tt>.call</tt>. If truthy, then matching warnings will be allowed.
      # If falsey then the method yields to the block without allowing the warning.
      #
      #   ActiveSupport::Deprecation.disallowed_behavior = :raise
      #   ActiveSupport::Deprecation.disallowed_warnings = [
      #     "something broke"
      #   ]
      #
      #   ActiveSupport::Deprecation.warn('something broke!')
      #   # => ActiveSupport::DeprecationException
      #
      #   ActiveSupport::Deprecation.allow ['something broke'] do
      #     ActiveSupport::Deprecation.warn('something broke!')
      #   end
      #   # => nil
      #
      #   ActiveSupport::Deprecation.allow ['something broke'], if: Rails.env.production? do
      #     ActiveSupport::Deprecation.warn('something broke!')
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

      def explicitly_allowed_warnings # :nodoc:
        @explicitly_allowed_warnings.value || self.class.explicitly_allowed_warnings
      end

      private
        def deprecation_disallowed?(message)
          return false if explicitly_allowed?(message)
          return true if disallowed_warnings == :all
          disallowed_warnings.any? do |rule|
            case rule
            when String, Symbol
              message.include?(rule.to_s)
            when Regexp
              rule.match?(message)
            end
          end
        end

        def explicitly_allowed?(message)
          return true if explicitly_allowed_warnings == :all
          Array(explicitly_allowed_warnings).any? do |rule|
            case rule
            when String, Symbol
              message.include?(rule.to_s)
            when Regexp
              rule.match?(message)
            end
          end
        end
    end
  end
end
