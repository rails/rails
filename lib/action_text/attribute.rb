module ActionText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      def has_rich_text(name)
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{name}
            self.rich_text_#{name} ||= ActionText::RichText.new(name: "#{name}", record: self)
          end

          def #{name}=(body)
            #{name}.body = body
          end
        CODE

        has_one :"rich_text_#{name}", -> { where(name: name) }, class_name: "ActionText::RichText", as: :record, inverse_of: :record, dependent: false

        scope :"with_rich_text_#{name}", -> { includes("rich_text_#{name}") }
      end


      # def has_rich_text(attribute_name)
      #   serialize(attribute_name, ActionText::Content)
      # 
      #   has_many_attached "#{attribute_name}_attachments"
      # 
      #   after_save do
      #     blobs = public_send(attribute_name).attachments.map(&:attachable)
      #     public_send("#{attribute_name}_attachments_blobs=", blobs)
      #   end
      # end
    end
  end
end
