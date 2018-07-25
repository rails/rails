# frozen_string_literal: true

module ActiveRecord
  module DynamicMatchers #:nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
      def inherited(child_class)
        child_class.generated_dynamic_matchers
        super
      end

      def generated_dynamic_matchers
        @generated_dynamic_matches ||= Module.new.tap { |mod| extend mod }
      end

      private
        def respond_to_missing?(name, _)
          if self == Base
            super
          else
            Method.match(self, name)&.valid? || super
            # match = Method.match(self, name)
            # match && match.valid? || super
          end
        end

        def method_missing(name, *arguments, &block)
          match = Method.match(self, name)

          if match&.valid?
            match.define
            send(name, *arguments, &block)
          else
            super
          end
        end
    end

    class Method
      @matchers = []

      class << self
        attr_reader :matchers

        def match(model, name)
          klass = matchers.find { |k| k.pattern.match?(name) }
          klass&.new(model, name)
        end

        def pattern
          @pattern ||= /\A#{prefix}_([_a-zA-Z]\w*)#{suffix}\Z/
        end

        def prefix
          raise NotImplementedError
        end

        def suffix
          ""
        end
      end

      attr_reader :model, :name, :attribute_names

      def initialize(model, name)
        @model           = model
        @name            = name.to_s
        @attribute_names = @name.match(self.class.pattern)[1].split("_and_")
        @attribute_names.map! { |n| @model.attribute_aliases[n] || n }
      end

      def valid?
        attribute_names.all? { |name| model.columns_hash[name] || model.reflect_on_aggregation(name.to_sym) }
      end

      def define
        model.generated_dynamic_matchers.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{name}(#{signature})
            #{body}
          end
        CODE
      end

      private

        def body
          "#{finder}(#{attributes_hash})"
        end

        # The parameters in the signature may have reserved Ruby words, in order
        # to prevent errors, we start each param name with `_`.
        def signature
          attribute_names.map { |name| "_#{name}" }.join(", ")
        end

        # Given that the parameters starts with `_`, the finder needs to use the
        # same parameter name.
        def attributes_hash
          "{" + attribute_names.map { |name| ":#{name} => _#{name}" }.join(",") + "}"
        end

        def finder
          raise NotImplementedError
        end
    end

    class FindBy < Method
      Method.matchers << self

      def self.prefix
        "find_by"
      end

      def finder
        "find_by"
      end
    end

    class FindByBang < Method
      Method.matchers << self

      def self.prefix
        "find_by"
      end

      def self.suffix
        "!"
      end

      def finder
        "find_by!"
      end
    end
  end
end
