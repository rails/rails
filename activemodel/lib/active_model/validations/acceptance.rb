module ActiveModel

  module Validations
    class AcceptanceValidator < EachValidator # :nodoc:
      def initialize(options)
        super({ allow_nil: true, accept: ["1", true] }.merge!(options))
        setup!(options[:class])
      end

      def validate_each(record, attribute, value)
        unless acceptable_option?(value)
          record.errors.add(attribute, :accepted, options.except(:accept, :allow_nil))
        end
      end

      private

        def setup!(klass)
          klass.include(LazilyDefineAttributes.new(AttributeDefinition.new(attributes)))
        end

        def acceptable_option?(value)
          Array(options[:accept]).include?(value)
        end

        class LazilyDefineAttributes < Module
          def initialize(attribute_definition)
            define_method(:respond_to_missing?) do |method_name, include_private=false|
              super(method_name, include_private) || attribute_definition.matches?(method_name)
            end

            define_method(:method_missing) do |method_name, *args, &block|
              if attribute_definition.matches?(method_name)
                attribute_definition.define_on(self.class)
                send(method_name, *args, &block)
              else
                super(method_name, *args, &block)
              end
            end
          end
        end

        class AttributeDefinition
          def initialize(attributes)
            @attributes = attributes.map(&:to_s)
          end

          def matches?(method_name)
            attr_name = convert_to_reader_name(method_name)
            attributes.include?(attr_name)
          end

          def define_on(klass)
            attr_readers = attributes.reject { |name| klass.attribute_method?(name) }
            attr_writers = attributes.reject { |name| klass.attribute_method?("#{name}=") }
            klass.send(:attr_reader, *attr_readers)
            klass.send(:attr_writer, *attr_writers)
          end

          protected

            attr_reader :attributes

          private

            def convert_to_reader_name(method_name)
              method_name.to_s.chomp("=")
            end
        end
    end

    module HelperMethods
      # Encapsulates the pattern of wanting to validate the acceptance of a
      # terms of service check box (or similar agreement).
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, message: 'must be abided'
      #   end
      #
      # If the database column does not exist, the +terms_of_service+ attribute
      # is entirely virtual. This check is performed only if +terms_of_service+
      # is not +nil+ and by default on save.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must be
      #   accepted").
      # * <tt>:accept</tt> - Specifies a value that is considered accepted.
      #   Also accepts an array of possible values. The default value is
      #   an array ["1", true], which makes it easy to relate to an HTML
      #   checkbox. This should be set to, or include, +true+ if you are validating
      #   a database column, since the attribute is typecast from "1" to +true+
      #   before validation.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information.
      def validates_acceptance_of(*attr_names)
        validates_with AcceptanceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
