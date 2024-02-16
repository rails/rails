# frozen_string_literal: true

# :markup: markdown

module ActionText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      # Provides access to a dependent RichText model that holds the body and
      # attachments for a single named rich text attribute. This dependent attribute
      # is lazily instantiated and will be auto-saved when it's been changed. Example:
      #
      #     class Message < ActiveRecord::Base
      #       has_rich_text :content
      #     end
      #
      #     message = Message.create!(content: "<h1>Funny times!</h1>")
      #     message.content? #=> true
      #     message.content.to_s # => "<h1>Funny times!</h1>"
      #     message.content.to_plain_text # => "Funny times!"
      #
      # The dependent RichText model will also automatically process attachments links
      # as sent via the Trix-powered editor. These attachments are associated with the
      # RichText model using Active Storage.
      #
      # If you wish to preload the dependent RichText model, you can use the named
      # scope:
      #
      #     Message.all.with_rich_text_content # Avoids N+1 queries when you just want the body, not the attachments.
      #     Message.all.with_rich_text_content_and_embeds # Avoids N+1 queries when you just want the body and attachments.
      #     Message.all.with_all_rich_text # Loads all rich text associations.
      #
      # #### Options
      #
      # *   `:encrypted` - Pass true to encrypt the rich text attribute. The
      #     encryption will be non-deterministic. See
      #     `ActiveRecord::Encryption::EncryptableRecord.encrypts`. Default: false.
      #
      # *   `:strict_loading` - Pass true to force strict loading. When omitted,
      #     `strict_loading:` will be set to the value of the
      #     `strict_loading_by_default` class attribute (false by default).
      #
      #
      # Note: Action Text relies on polymorphic associations, which in turn store
      # class names in the database. When renaming classes that use `has_rich_text`,
      # make sure to also update the class names in the
      # `action_text_rich_texts.record_type` polymorphic type column of the
      # corresponding rows.
      def has_rich_text(name, encrypted: false, strict_loading: strict_loading_by_default)
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

        rich_text_class_name = encrypted ? "ActionText::EncryptedRichText" : "ActionText::RichText"
        has_one :"rich_text_#{name}", -> { where(name: name) },
          class_name: rich_text_class_name, as: :record, inverse_of: :record, autosave: true, dependent: :destroy,
          strict_loading: strict_loading

        scope :"with_rich_text_#{name}", -> { includes("rich_text_#{name}") }
        scope :"with_rich_text_#{name}_and_embeds", -> { includes("rich_text_#{name}": { embeds_attachments: :blob }) }
      end

      # Eager load all dependent RichText models in bulk.
      def with_all_rich_text
        includes(rich_text_association_names)
      end

      # Returns the names of all rich text associations.
      def rich_text_association_names
        reflect_on_all_associations(:has_one).collect(&:name).select { |n| n.start_with?("rich_text_") }
      end
    end
  end
end
