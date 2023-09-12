# frozen_string_literal: true

module ActionText
  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      # Add a named rich text attribute.
      # By default, a separate model holding both body and attachments is used.
      # This dependent attribute is lazily instantiated and will be auto-saved when it's been changed. Example:
      #
      #   class Message < ActiveRecord::Base
      #     has_rich_text :content
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
      #   Message.all.with_all_rich_text # Loads all rich text associations.
      #
      # If a column: parameter is passed with the name of a column, it will be used instead of a separate model to hold data.
      # Example:
      #
      #   create_table :messages do |t|
      #     t.string   :content
      #   end
      #
      #   class Message < ActiveRecord::Base
      #     rich_text_column :content
      #   end
      #
      # ==== Options
      #
      # * <tt>:encrypted</tt> - Pass true to encrypt the rich text attribute. The encryption will be non-deterministic. See
      #   +ActiveRecord::Encryption::EncryptableRecord.encrypts+. Has no effect if column storage is used. Default: false.
      #
      # * <tt>:strict_loading</tt> - Pass true to force strict loading. When omitted, <tt>strict_loading:</tt> will be
      #   set to the value of the <tt>strict_loading_by_default</tt> class attribute. Has no effect if column storage
      #   is used. Default: false.
      #
      #
      # * <tt>:column</tt> - Pass true to use a column named after the attribute, or the name of another column.
      #   This column will the be used to store data. Default: false.
      def has_rich_text(name, encrypted: false, strict_loading: strict_loading_by_default, column: false)
        if column
          # Use attribute name as default column name
          column = name if column.is_a?(TrueClass)
          rich_text_column(name, column: column)
        else
          rich_text_table(name, encrypted: encrypted, strict_loading: strict_loading)
        end
      end

      # Associated model storage
      def rich_text_table(name, encrypted: false, strict_loading: strict_loading_by_default)
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

      def rich_text_column(name, column:)
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          has_many_attached :#{name}_rich_text_embeds

          before_save do
            self.#{name}_rich_text_embeds = #{name}.body.attachables.grep(ActiveStorage::Blob).uniq if #{name}.body.present?
          end

          def #{name}_rich_text_column_name
            "#{column}"
          end

          def #{name}
            @rich_text_column_#{name} ||= ActionText::RichTextColumn.new(content: read_attribute(#{name}_rich_text_column_name), embeds: #{name}_rich_text_embeds)
          end

          def #{name}?
            #{name}.body.present?
          end

          def #{name}=(content)
            #{name}.body = content
            write_attribute(#{name}_rich_text_column_name, #{name}.body.to_html)
          end
        CODE
      end

      # Eager load all dependent RichText models in bulk.
      def with_all_rich_text
        eager_load(rich_text_association_names)
      end

      def rich_text_association_names
        reflect_on_all_associations(:has_one).collect(&:name).select { |n| n.start_with?("rich_text_") }
      end
    end
  end
end
