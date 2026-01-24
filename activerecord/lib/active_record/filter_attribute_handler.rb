# frozen_string_literal: true

module ActiveRecord
  class FilterAttributeHandler # :nodoc:
    class << self
      def on_sensitive_attribute_declared(&block)
        @sensitive_attribute_declaration_listeners ||= Concurrent::Array.new
        @sensitive_attribute_declaration_listeners << block
      end

      def sensitive_attribute_was_declared(klass, list)
        @sensitive_attribute_declaration_listeners&.each do |block|
          block.call(klass, list)
        end
      end
    end

    def initialize(app)
      @app = app
      @attributes_by_class = Concurrent::Map.new
      @collecting = true
    end

    def enable
      install_collecting_hook

      apply_collected_attributes
      @collecting = false
    end

    private
      attr_reader :app

      def install_collecting_hook
        self.class.on_sensitive_attribute_declared do |klass, list|
          attribute_was_declared(klass, list)
        end
      end

      def attribute_was_declared(klass, list)
        if collecting?
          collect_for_later(klass, list)
        else
          apply_filter(klass, list)
        end
      end

      def apply_collected_attributes
        @attributes_by_class.each do |klass, list|
          apply_filter(klass, list)
        end
      end

      def collecting?
        @collecting
      end

      def collect_for_later(klass, list)
        @attributes_by_class[klass] ||= Concurrent::Array.new
        @attributes_by_class[klass] += list
      end

      def apply_filter(klass, list)
        list.each do |attribute|
          next if klass.abstract_class? || klass == Base

          klass_name = klass.name ? klass.model_name.element : nil
          filter = [klass_name, attribute.to_s].compact.join(".")
          app.config.filter_parameters << filter unless app.config.filter_parameters.include?(filter)
        end
      end
  end
end
