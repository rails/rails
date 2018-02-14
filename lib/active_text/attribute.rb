module ActiveText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      def active_text_attribute(attribute_name)
        serialize(attribute_name, ActiveText::Content)

        has_many_attached "#{attribute_name}_attachments"

        after_save do
          blobs = public_send(attribute_name).attachments.map(&:attachable)
          public_send("#{attribute_name}_attachments_blobs=", blobs)
        end
      end
    end
  end
end
