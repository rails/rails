# frozen_string_literal: true

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
          define_attributes = LazilyDefineAttributes.new(attributes)
          klass.include(define_attributes) unless klass.included_modules.include?(define_attributes)
        end

        def acceptable_option?(value)
          Array(options[:accept]).include?(value)
        end

        class LazilyDefineAttributes < Module
          def initialize(attributes)
            @attributes = attributes.map(&:to_s)
          end

          def included(klass)
            @lock = Mutex.new
            mod = self

            define_method(:respond_to_missing?) do |method_name, include_private = false|
              mod.define_on(klass)
              super(method_name, include_private) || mod.matches?(method_name)
            end

            define_method(:method_missing) do |method_name, *args, &block|
              mod.define_on(klass)
              if mod.matches?(method_name)
                send(method_name, *args, &block)
              else
                super(method_name, *args, &block)
              end
            end
          end

          def matches?(method_name)
            attr_name = method_name.to_s.chomp("=")
            attributes.any? { |name| name == attr_name }
          end

          def define_on(klass)
            @lock&.synchronize do
              return unless @lock

              attr_readers = attributes.reject { |name| klass.attribute_method?(name) }
              attr_writers = attributes.reject { |name| klass.attribute_method?("#{name}=") }

              attr_reader(*attr_readers)
              attr_writer(*attr_writers)

              remove_method :respond_to_missing?
              remove_method :method_missing

              @lock = nil
            end
          end

          def ==(other)
            self.class == other.class && attributes == other.attributes
          end

          protected
            attr_reader :attributes
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
      # See <tt>ActiveModel::Validations#validates</tt> for more information.
      def validates_acceptance_of(*attr_names)
        validates_with AcceptanceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
