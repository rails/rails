# frozen_string_literal: true

module ActionText
  # = Action Text \RichText
  #
  # The RichText record holds the content produced by the Trix editor in a serialized +body+ attribute.
  # It also holds all the references to the embedded files, which are stored using Active Storage.
  # This record is then associated with the Active Record model the application desires to have
  # rich text content using the +has_rich_text+ class method.
  #
  #   class Message < ActiveRecord::Base
  #     has_rich_text :content
  #   end
  #
  #   message = Message.create!(content: "<h1>Funny times!</h1>")
  #   message.content #=> #<ActionText::RichText....
  #   message.content.to_s # => "<h1>Funny times!</h1>"
  #   message.content.to_plain_text # => "Funny times!"
  #
  class RichText < Record
    self.table_name = "action_text_rich_texts"

    serialize :body, coder: ActionText::Content
    delegate :to_s, :nil?, to: :body

    belongs_to :record, polymorphic: true, touch: true
    has_many_attached :embeds

    before_save do
      self.embeds = body.attachables.grep(ActiveStorage::Blob).uniq if body.present?
    end

    # Returns the +body+ attribute as plain text with all HTML tags removed.
    #
    #   message = Message.create!(content: "<h1>Funny times!</h1>")
    #   message.content.to_plain_text # => "Funny times!"
    def to_plain_text
      body&.to_plain_text.to_s
    end

    # Returns the +body+ attribute in a format that makes it editable in the Trix
    # editor. Previews of attachments are rendered inline.
    #
    #   content = "<h1>Funny Times!</h1><figure data-trix-attachment='{\"sgid\":\"..."\}'></figure>"
    #   message = Message.create!(content: content)
    #   message.content.to_trix_html # =>
    #   # <div class="trix-content">
    #   #   <h1>Funny times!</h1>
    #   #   <figure data-trix-attachment='{\"sgid\":\"..."\}'>
    #   #      <img src="http://example.org/rails/active_storage/.../funny.jpg">
    #   #   </figure>
    #   # </div>
    def to_trix_html
      body&.to_trix_html
    end

    delegate :blank?, :empty?, :present?, to: :to_plain_text
  end
end

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichText
