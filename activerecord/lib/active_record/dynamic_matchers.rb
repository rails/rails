# frozen_string_literal: true

module ActiveRecord
  module DynamicMatchers # :nodoc:
    private
      def respond_to_missing?(name, _)
        if self == Base
          super
        else
          super || begin
            match = Method.match(name)
            match && match.valid?(self, name)
          end
        end
      end

      def method_missing(name, ...)
        match = Method.match(name)

        if match && match.valid?(self, name)
          match.define(self, name)
          send(name, ...)
        else
          super
        end
      end

      class Method
        class << self
          def match(name)
            FindBy.match?(name) || FindByBang.match?(name)
          end

          def valid?(model, name)
            attribute_names(model, name.to_s).all? { |name| model.columns_hash[name] || model.reflect_on_aggregation(name.to_sym) }
          end

          def define(model, name)
            model.class_eval <<-CODE, __FILE__, __LINE__ + 1
            def self.#{name}(#{signature(model, name)})
              #{body(model, name)}
            end
            CODE
          end

          private
            def make_pattern(prefix, suffix)
              /\A#{prefix}_([_a-zA-Z]\w*)#{suffix}\Z/
            end

            def attribute_names(model, name)
              attribute_names = name.match(pattern)[1].split("_and_")
              attribute_names.map! { |name| model.attribute_aliases[name] || name }
            end

            def body(model, method_name)
              "#{finder}(#{attributes_hash(model, method_name)})"
            end

            # The parameters in the signature may have reserved Ruby words, in order
            # to prevent errors, we start each param name with `_`.
            def signature(model, method_name)
              attribute_names(model, method_name.to_s).map { |name| "_#{name}" }.join(", ")
            end

            # Given that the parameters starts with `_`, the finder needs to use the
            # same parameter name.
            def attributes_hash(model, method_name)
              "{" + attribute_names(model, method_name).map { |name| ":#{name} => _#{name}" }.join(",") + "}"
            end
        end
      end

      class FindBy < Method
        @pattern = make_pattern("find_by", "")

        class << self
          attr_reader :pattern

          def match?(name)
            pattern.match?(name) && self
          end

          def finder
            "find_by"
          end
        end
      end

      class FindByBang < Method
        @pattern = make_pattern("find_by", "!")

        class << self
          attr_reader :pattern

          def match?(name)
            pattern.match?(name) && self
          end

          def finder
            "find_by!"
          end
        end
      end
  end
end
