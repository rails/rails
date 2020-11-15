# frozen_string_literal: true

module ActionText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      # Provides access to a dependent RichText model that holds the body and attachments for a single named rich text attribute.
      # This dependent attribute is lazily instantiated and will be auto-saved when it's been changed. Example:
      #
      # [:strict_loading]
      #   Enforces strict loading every time an associated record is loaded through this association.
      #
      #   class Message < ActiveRecord::Base
      #     has_rich_text :content
      #     has_rich_text :content, strict_loading: true
      #   end
      #
      #   message = Message.create!(content: "<h1>Funny times!</h1>")
      #   message.content? #=> true
      #   message.content.to_s # => "<h1>Funny times!</h1>"
      #   message.content.to_plain_text # => "Funny times!"
      #
      # The dependent RichText model will also automatically process attachments links as sent via the Trix-powered editor.
      # These attachments are associated with the RichText model using Active Storage.
      #
      # If you wish to preload the dependent RichText model, you can use the named scope:
      #
      #   Message.all.with_rich_text_content # Avoids N+1 queries when you just want the body, not the attachments.
      #   Message.all.with_rich_text_content_and_embeds # Avoids N+1 queries when you just want the body and attachments.
      def has_rich_text(name, strict_loading: false)
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{name}
            rich_text_#{name} || build_rich_text_#{name}
          end

          def #{name}?
            rich_text_#{name}.present?
          end

          def #{name}=(body)
            self.#{name}.body = body
          end
        CODE

        has_one :"rich_text_#{name}", -> { where(name: name) },
          class_name: "ActionText::RichText", as: :record, inverse_of: :record, autosave: true, dependent: :destroy, strict_loading: strict_loading

        scope :"with_rich_text_#{name}", -> { includes("rich_text_#{name}") }
        scope :"with_rich_text_#{name}_and_embeds", -> { includes("rich_text_#{name}": { embeds_attachments: :blob }) }
      end
    end
  end
end
