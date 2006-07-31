module ActiveRecord
  module AttributeMethods #:nodoc:
    DEFAULT_SUFFIXES = %w(= ? _before_type_cast)

    def self.included(base)
      base.extend ClassMethods
      base.attribute_method_suffix *DEFAULT_SUFFIXES
    end

    # Declare and check for suffixed attribute methods.
    module ClassMethods
      # Declare a method available for all attributes with the given suffix.
      # Uses method_missing and respond_to? to rewrite the method
      #   #{attr}#{suffix}(*args, &block)
      # to
      #   attribute#{suffix}(#{attr}, *args, &block)
      #
      # An attribute#{suffix} instance method must exist and accept at least
      # the attr argument.
      #
      # For example:
      #   class Person < ActiveRecord::Base
      #     attribute_method_suffix '_changed?'
      #
      #     private
      #       def attribute_changed?(attr)
      #         ...
      #       end
      #   end
      #
      #   person = Person.find(1)
      #   person.name_changed?    # => false
      #   person.name = 'Hubert'
      #   person.name_changed?    # => true
      def attribute_method_suffix(*suffixes)
        attribute_method_suffixes.concat suffixes
        rebuild_attribute_method_regexp
      end

      # Returns MatchData if method_name is an attribute method.
      def match_attribute_method?(method_name)
        rebuild_attribute_method_regexp unless defined?(@@attribute_method_regexp) && @@attribute_method_regexp
        @@attribute_method_regexp.match(method_name)
      end

      private
        # Suffixes a, ?, c become regexp /(a|\?|c)$/
        def rebuild_attribute_method_regexp
          suffixes = attribute_method_suffixes.map { |s| Regexp.escape(s) }
          @@attribute_method_regexp = /(#{suffixes.join('|')})$/.freeze
        end

        # Default to =, ?, _before_type_cast
        def attribute_method_suffixes
          @@attribute_method_suffixes ||= []
        end
    end

    private
      # Handle *? for method_missing.
      def attribute?(attribute_name)
        query_attribute(attribute_name)
      end

      # Handle *= for method_missing.
      def attribute=(attribute_name, value)
        write_attribute(attribute_name, value)
      end

      # Handle *_before_type_cast for method_missing.
      def attribute_before_type_cast(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end
  end
end
