# frozen_string_literal: true

module ActionText
  # = Action Text \RichTextColumn
  #
  # The RichText object holds the content produced by the Trix editor in a serialized +body+ attribute.
  # This object is stored serialized in the Active Record model column specified by the +rich_text_column+ class method.
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
  class RichTextColumn
    attr_reader :body
    attr_accessor :embeds

    delegate :nil?, :to_s, to: :body

    def initialize(content: nil, embeds: [])
      self.body = content unless content.nil?
      self.embeds = embeds
    end

    # Store HTML content as ActionText::Content
    def body=(content)
      if content.is_a?(RichTextColumn)
        @body = content.body
      else
        @body = ActionText::Content.new(content)
      end
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

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichTextColumn
