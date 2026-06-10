# frozen_string_literal: true

module ActiveRecord
  module Encryption
    class AutoFilteredParameters # :nodoc:
      def initialize(app)
        @app = app
        @attributes_by_class = Concurrent::Map.new
        @collecting = true

        install_collecting_hook
      end

      def enable
        apply_collected_attributes
        @collecting = false
      end

      private
        attr_reader :app

        def install_collecting_hook
          ActiveRecord::Encryption.on_encrypted_attribute_declared do |klass, attribute|
            attribute_was_declared(klass, attribute)
          end
        end

        def attribute_was_declared(klass, attribute)
          if collecting?
            collect_for_later(klass, attribute)
          else
            apply_filter(klass, attribute)
          end
        end

        def apply_collected_attributes
          @attributes_by_class.each do |klass, attributes|
            attributes.each do |attribute|
              apply_filter(klass, attribute)
            end
          end
        end

        def collecting?
          @collecting
        end

        def collect_for_later(klass, attribute)
          @attributes_by_class[klass] ||= Concurrent::Array.new
          @attributes_by_class[klass] << attribute
        end

        def apply_filter(klass, attribute)
          filter = [("#{klass.model_name.element}" if klass.name), attribute.to_s].compact.join(".")
          unless excluded_from_filter_parameters?(filter)
            filters = [ filter, nested_attributes_filter(klass, attribute) ].compact
            filters.each do |filter_parameter|
              app.config.filter_parameters << filter_parameter unless app.config.filter_parameters.include?(filter_parameter)
            end
            klass.filter_attributes |= [ attribute ]
          end
        end

        # Nested attribute params (e.g. <tt>pirate_attributes</tt>, <tt>pirates_attributes</tt>)
        # don't match the model-scoped filter, so register a variant covering
        # +accepts_nested_attributes_for+ params named after the model, tolerating
        # an intermediate index key ("0", "new0", ...).
        def nested_attributes_filter(klass, attribute)
          return unless klass.name

          element = klass.model_name.element
          names = [ element, element.pluralize ].uniq.map { |name| Regexp.escape(name) }
          /(?:#{names.join("|")})_attributes\.(?:[^.]+\.)?#{Regexp.escape(attribute.to_s)}/i
        end

        def excluded_from_filter_parameters?(filter_parameter)
          ActiveRecord::Encryption.config.excluded_from_filter_parameters.find { |excluded_filter| excluded_filter.to_s == filter_parameter }
        end
    end
  end
end
