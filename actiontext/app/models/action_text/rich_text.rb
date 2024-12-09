# frozen_string_literal: true

# :markup: markdown

module ActionText
  # # Action Text RichText
  #
  # The RichText record holds the content produced by the Trix editor in a
  # serialized `body` attribute. It also holds all the references to the embedded
  # files, which are stored using Active Storage. This record is then associated
  # with the Active Record model the application desires to have rich text content
  # using the `has_rich_text` class method.
  #
  #     class Message < ActiveRecord::Base
  #       has_rich_text :content
  #     end
  #
  #     message = Message.create!(content: "<h1>Funny times!</h1>")
  #     message.content #=> #<ActionText::RichText....
  #     message.content.to_s # => "<h1>Funny times!</h1>"
  #     message.content.to_plain_text # => "Funny times!"
  #
  #     message = Message.create!(content: "<div onclick='action()'>safe<script>unsafe</script></div>")
  #     message.content #=> #<ActionText::RichText....
  #     message.content.to_s # => "<div>safeunsafe</div>"
  #     message.content.to_plain_text # => "safeunsafe"
  class RichText < Record
    ##
    # :method: to_s
    #
    # Safely transforms RichText into an HTML String.
    #
    #     message = Message.create!(content: "<h1>Funny times!</h1>")
    #     message.content.to_s # => "<h1>Funny times!</h1>"
    #
    #     message = Message.create!(content: "<div onclick='action()'>safe<script>unsafe</script></div>")
    #     message.content.to_s # => "<div>safeunsafe</div>"

    serialize :body, coder: ActionText::Content
    delegate :to_s, :nil?, to: :body

    ##
    # :method: record
    #
    # Returns the associated record.
    belongs_to :record, polymorphic: true, touch: true

    ##
    # :method: embeds
    #
    # Returns the `ActiveStorage::Attachment` records from the embedded files.
    #
    # Attached `ActiveStorage::Blob` records are extracted from the `body`
    # in a # [before_validation](/classes/ActiveModel/Validations/Callbacks/ClassMethods.html#method-i-before_validation) callback.
    has_many_attached :embeds

    before_validation do
      self.embeds = body.attachables.grep(ActiveStorage::Blob).uniq if body.present?
    end

    # Returns a plain-text version of the markup contained by the `body` attribute,
    # with tags removed but HTML entities encoded.
    #
    #     message = Message.create!(content: "<h1>Funny times!</h1>")
    #     message.content.to_plain_text # => "Funny times!"
    #
    # NOTE: that the returned string is not HTML safe and should not be rendered in
    # browsers.
    #
    #     message = Message.create!(content: "&lt;script&gt;alert()&lt;/script&gt;")
    #     message.content.to_plain_text # => "<script>alert()</script>"
    def to_plain_text
      body&.to_plain_text.to_s
    end

    # Returns the `body` attribute in a format that makes it editable in the Trix
    # editor. Previews of attachments are rendered inline.
    #
    #     content = "<h1>Funny Times!</h1><figure data-trix-attachment='{\"sgid\":\"..."\}'></figure>"
    #     message = Message.create!(content: content)
    #     message.content.to_trix_html # =>
    #     # <div class="trix-content">
    #     #   <h1>Funny times!</h1>
    #     #   <figure data-trix-attachment='{\"sgid\":\"..."\}'>
    #     #      <img src="http://example.org/rails/active_storage/.../funny.jpg">
    #     #   </figure>
    #     # </div>
    def to_trix_html
      body&.to_trix_html
    end

    delegate :blank?, :empty?, :present?, to: :to_plain_text
  end
end

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichText
