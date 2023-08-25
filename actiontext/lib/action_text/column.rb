# frozen_string_literal: true

module ActionText
  module Column
    extend ActiveSupport::Concern

    class_methods do
      # Enable rich text support for a column of the model's table, instead of using an association.
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
      #   message = Message.create!(content: "<h1>Funny times!</h1>")
      #   message.content? #=> true
      #   message.content.to_s # => "<h1>Funny times!</h1>"
      #   message.content.to_plain_text # => "Funny times!"
      #
      # Attachments links sent via the Trix-powered editor will be processed and associated with the model using Active Storage.
      def rich_text_column(name)
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          has_many_attached :#{name}_rich_text_embeds

          before_save do
            self.#{name}_rich_text_embeds = #{name}.body.attachables.grep(ActiveStorage::Blob).uniq if #{name}.body.present?
          end

          def #{name}
            @rich_text_column_#{name} ||= ActionText::RichTextColumn.new(content: read_attribute(:#{name}), embeds: #{name}_rich_text_embeds)
          end

          def #{name}?
            #{name}.body.present?
          end

          def #{name}=(content)
            #{name}.body = content
            write_attribute(:#{name}, #{name}.body.to_html)
          end
        CODE

      end
    end
  end
end
