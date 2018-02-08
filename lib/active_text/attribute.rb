module ActiveText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      def active_text_attribute(attribute_name)
        serialize(attribute_name, ActiveText::Content)
      end
    end
  end
end
