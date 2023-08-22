# frozen_string_literal: true

module ActiveSupport
  class Deprecation
    # A managed collection of deprecators. Configuration methods, such as
    # #behavior=, affect all deprecators in the collection. Additionally, the
    # #silence method silences all deprecators in the collection for the
    # duration of a given block.
    class Deprecators
      def initialize
        @options = {}
        @deprecators = {}
      end

      # Returns a deprecator added to this collection via #[]=.
      def [](name)
        @deprecators[name]
      end

      # Adds a given +deprecator+ to this collection. The deprecator will be
      # immediately configured with any options previously set on this
      # collection.
      #
      #   deprecators = ActiveSupport::Deprecation::Deprecators.new
      #   deprecators.debug = true
      #
      #   foo_deprecator = ActiveSupport::Deprecation.new("2.0", "Foo")
      #   foo_deprecator.debug    # => false
      #
      #   deprecators[:foo] = foo_deprecator
      #   deprecators[:foo].debug # => true
      #   foo_deprecator.debug    # => true
      #
      def []=(name, deprecator)
        apply_options(deprecator)
        @deprecators[name] = deprecator
      end

      # Iterates over all deprecators in this collection. If no block is given,
      # returns an +Enumerator+.
      def each(&block)
        return to_enum(__method__) unless block
        @deprecators.each_value(&block)
      end

      # Sets the silenced flag for all deprecators in this collection.
      def silenced=(silenced)
        set_option(:silenced, silenced)
      end

      # Sets the debug flag for all deprecators in this collection.
      def debug=(debug)
        set_option(:debug, debug)
      end

      # Sets the deprecation warning behavior for all deprecators in this
      # collection.
      #
      # See ActiveSupport::Deprecation#behavior=.
      def behavior=(behavior)
        set_option(:behavior, behavior)
      end

      # Sets the disallowed deprecation warning behavior for all deprecators in
      # this collection.
      #
      # See ActiveSupport::Deprecation#disallowed_behavior=.
      def disallowed_behavior=(disallowed_behavior)
        set_option(:disallowed_behavior, disallowed_behavior)
      end

      # Sets the disallowed deprecation warnings for all deprecators in this
      # collection.
      #
      # See ActiveSupport::Deprecation#disallowed_warnings=.
      def disallowed_warnings=(disallowed_warnings)
        set_option(:disallowed_warnings, disallowed_warnings)
      end

      # Silences all deprecators in this collection for the duration of the
      # given block.
      #
      # See ActiveSupport::Deprecation#silence.
      def silence(&block)
        each { |deprecator| deprecator.begin_silence }
        block.call
      ensure
        each { |deprecator| deprecator.end_silence }
      end

      private
        def set_option(name, value)
          @options[name] = value
          each { |deprecator| deprecator.public_send("#{name}=", value) }
        end

        def apply_options(deprecator)
          @options.each do |name, value|
            deprecator.public_send("#{name}=", value)
          end
        end
    end
  end
end
