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

    cattr_accessor :editors, instance_accessor: false, default: {}.freeze
    cattr_accessor :editor, instance_accessor: false

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
    # Returns the ActiveStorage::Attachment records from the embedded files.
    #
    # Attached ActiveStorage::Blob records are extracted from the `body`
    # in a {before_validation}[rdoc-ref:ActiveModel::Validations::Callbacks::ClassMethods#before_validation] callback.
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
    # browsers without additional sanitization.
    #
    #     message = Message.create!(content: "&lt;script&gt;alert()&lt;/script&gt;")
    #     message.content.to_plain_text # => "<script>alert()</script>"
    def to_plain_text
      body&.to_plain_text.to_s
    end

    # Returns a Markdown version of the markup contained by the `body` attribute.
    #
    #     message = Message.create!(content: "<h1>Funny times!</h1>")
    #     message.content.to_markdown # => "# Funny times!"
    #
    #     message = Message.create!(content: "<p>Hello <strong>world</strong></p>")
    #     message.content.to_markdown # => "Hello **world**"
    #
    # When +attachment_links+ is true, ActiveStorage blob attachments generate Markdown links with
    # URLs. This requires a rendering context (e.g., controller or mailer action) and will raise if
    # URL generation fails.
    #
    # NOTE: that the returned string is not HTML safe and should not be rendered in
    # browsers without additional sanitization.
    def to_markdown(attachment_links: false)
      body&.to_markdown(attachment_links: attachment_links).to_s
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
      to_editor_html
    end
    deprecate to_trix_html: :to_editor_html, deprecator: ActionText.deprecator

    # Returns the `body` attribute in a format that makes it editable in the
    # editor. Previews of attachments are rendered inline.
    #
    #     content = "<h1>Funny Times!</h1><figure data-action-text-attachment='{\"sgid\":\"..."\}'></figure>"
    #     message = Message.create!(content: content)
    #     message.content.to_editor_html # =>
    #     # <div class="trix-content">
    #     #   <h1>Funny times!</h1>
    #     #   <figure data-action-text-attachment='{\"sgid\":\"..."\}'>
    #     #      <img src="http://example.org/rails/active_storage/.../funny.jpg">
    #     #   </figure>
    #     # </div>
    def to_editor_html
      body&.to_editor_html
    end

    delegate :blank?, :empty?, :present?, to: :to_plain_text

    # Saves the RichText record, transparently handling a concurrent-save race
    # condition that can occur when two requests create rich text for the same
    # record and attribute at the same time.
    #
    # Because +has_rich_text+ is backed by an autosaved +has_one+ association,
    # two concurrent saves of the parent record may both build a new RichText
    # in memory and attempt to INSERT it. The database unique index on
    # <tt>(record_type, record_id, name)</tt> guarantees that only one succeeds.
    #
    # When the loser raises +ActiveRecord::RecordNotUnique+, this method finds
    # the winning row, updates it with the current body (and any embeds
    # extracted by the +before_validation+ callback), adopts its primary key,
    # and marks the in-memory object as persisted so the parent save can
    # continue normally.
    #
    # RecordNotUnique errors on already-persisted records are re-raised.
    def save(**options)
      super
    rescue ActiveRecord::RecordNotUnique => error
      if new_record?
        if (existing = self.class.find_by(record: record, name: name))
          existing.update!(body: body)
          self.id = existing.id
          @new_record = false
          @previously_new_record = true
          @transaction_state = nil
          true
        else
          raise error
        end
      else
        raise error
      end
    end
  end
end

ActiveSupport.run_load_hooks :action_text_rich_text, ActionText::RichText
