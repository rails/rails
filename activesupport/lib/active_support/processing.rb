# frozen_string_literal: true

module ActiveSupport
  module Processing
    extend Concern

    included do
      def process(element)
        id         = identify element
        on_element = :"on_#{id}"

        if respond_to? on_element
          public_send(on_element, element)
        else
          handler_missing(element)
        end
      end

      def process_each(elements)
        elements.filter_map do |element|
          process element
        end
      end

      def handler_missing(element)
      end
    end

    class_methods do
      def process(elements)
        new.process_each(elements)
      end
    end
  end
end
