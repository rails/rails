# frozen_string_literal: true

require "active_support/core_ext/string/inquiry"

module ActiveRecord
  # == Delegated types
  #
  # Class hierarchies can map to relational database tables in many ways. Active Record, for example, offers
  # purely abstract classes, where the superclass doesn't persist any attributes, and single-table inheritance,
  # where all attributes from all levels of the hierarchy are represented in a single table. Both have their
  # places, but neither are without their drawbacks.
  #
  # The problem with purely abstract classes is that all concrete subclasses must persist all the shared
  # attributes themselves in their own tables (also known as class-table inheritance). This makes it hard to
  # do queries across the hierarchy. For example, imagine you have the following hierarchy:
  #
  #   Entry < ApplicationRecord
  #   Message < Entry
  #   Comment < Entry
  #
  # How do you show a feed that has both +Message+ and +Comment+ records, which can be easily paginated?
  # Well, you can't! Messages are backed by a messages table and comments by a comments table. You can't
  # pull from both tables at once and use a consistent OFFSET/LIMIT scheme.
  #
  # You can get around the pagination problem by using single-table inheritance, but now you're forced into
  # a single mega table with all the attributes from all subclasses. No matter how divergent. If a Message
  # has a subject, but the comment does not, well, now the comment does anyway! So STI works best when there's
  # little divergence between the subclasses and their attributes.
  #
  # But there's a third way: Delegated types. With this approach, the "superclass" is a concrete class
  # that is represented by its own table, where all the superclass attributes that are shared amongst all the
  # "subclasses" are stored. And then each of the subclasses have their own individual tables for additional
  # attributes that are particular to their implementation. This is similar to what's called multi-table
  # inheritance in Django, but instead of actual inheritance, this approach uses delegation to form the
  # hierarchy and share responsibilities.
  #
  # Let's look at that entry/message/comment example using delegated types:
  #
  #   # Schema: entries[ id, account_id, creator_id, created_at, updated_at, entryable_type, entryable_id ]
  #   class Entry < ApplicationRecord
  #     belongs_to :account
  #     belongs_to :creator
  #     delegated_type :entryable, types: %w[ Message Comment ]
  #   end
  #
  #   module Entryable
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       has_one :entry, as: :entryable, touch: true
  #     end
  #   end
  #
  #   # Schema: messages[ id, subject ]
  #   class Message < ApplicationRecord
  #     include Entryable
  #     has_rich_text :content
  #   end
  #
  #   # Schema: comments[ id, content ]
  #   class Comment < ApplicationRecord
  #     include Entryable
  #   end
  #
  # As you can see, neither +Message+ nor +Comment+ are meant to stand alone. Crucial metadata for both classes
  # resides in the +Entry+ "superclass". But the +Entry+ absolutely can stand alone in terms of querying capacity
  # in particular. You can now easily do things like:
  #
  #   Account.entries.order(created_at: :desc).limit(50)
  #
  # Which is exactly what you want when displaying both comments and messages together. The entry itself can
  # be rendered as its delegated type easily, like so:
  #
  #   # entries/_entry.html.erb
  #   <%= render "entries/entryables/#{entry.entryable_name}", entry: entry %>
  #
  #   # entries/entryables/_message.html.erb
  #   <div class="message">
  #     Posted on <%= entry.created_at %> by <%= entry.creator.name %>: <%= entry.message.content %>
  #   </div>
  #
  #   # entries/entryables/_comment.html.erb
  #   <div class="comment">
  #     <%= entry.creator.name %> said: <%= entry.comment.content %>
  #   </div>
  #
  # == Sharing behavior with concerns and controllers
  #
  # The entry "superclass" also serves as a perfect place to put all that shared logic that applies to both
  # messages and comments, and which acts primarily on the shared attributes. Imagine:
  #
  #   class Entry < ApplicationRecord
  #     include Eventable, Forwardable, Redeliverable
  #   end
  #
  # Which allows you to have controllers for things like +ForwardsController+ and +RedeliverableController+
  # that both act on entries, and thus provide the shared functionality to both messages and comments.
  #
  # == Creating new records
  #
  # You create a new record that uses delegated typing by creating the delegator and delegatee at the same time,
  # like so:
  #
  #   Entry.create! entryable: Comment.new(content: "Hello!"), creator: Current.user
  #
  # If you need more complicated composition, or you need to perform dependent validation, you should build a factory
  # method or class to take care of the complicated needs. This could be as simple as:
  #
  #   class Entry < ApplicationRecord
  #     def self.create_with_comment(content, creator: Current.user)
  #       create! entryable: Comment.new(content: content), creator: creator
  #     end
  #   end
  #
  # == Adding further delegation
  #
  # The delegated type shouldn't just answer the question of what the underlying class is called. In fact, that's
  # an anti-pattern most of the time. The reason you're building this hierarchy is to take advantage of polymorphism.
  # So here's a simple example of that:
  #
  #   class Entry < ApplicationRecord
  #     delegated_type :entryable, types: %w[ Message Comment ]
  #     delegates :title, to: :entryable
  #   end
  #
  #   class Message < ApplicationRecord
  #     def title
  #       subject
  #     end
  #   end
  #
  #   class Comment < ApplicationRecord
  #     def title
  #       content.truncate(20)
  #     end
  #   end
  #
  # Now you can list a bunch of entries, call +Entry#title+, and polymorphism will provide you with the answer.
  module DelegatedType
    # Defines this as a class that'll delegate its type for the passed +role+ to the class references in +types+.
    # That'll create a polymorphic +belongs_to+ relationship to that +role+, and it'll add all the delegated
    # type convenience methods:
    #
    #   class Entry < ApplicationRecord
    #     delegated_type :entryable, types: %w[ Message Comment ], dependent: :destroy
    #   end
    #
    #   Entry#entryable_class # => +Message+ or +Comment+
    #   Entry#entryable_name  # => "message" or "comment"
    #   Entry.messages        # => Entry.where(entryable_type: "Message")
    #   Entry#message?        # => true when entryable_type == "Message"
    #   Entry#message         # => returns the message record, when entryable_type == "Message", otherwise nil
    #   Entry#message_id      # => returns entryable_id, when entryable_type == "Message", otherwise nil
    #   Entry.comments        # => Entry.where(entryable_type: "Comment")
    #   Entry#comment?        # => true when entryable_type == "Comment"
    #   Entry#comment         # => returns the comment record, when entryable_type == "Comment", otherwise nil
    #   Entry#comment_id      # => returns entryable_id, when entryable_type == "Comment", otherwise nil
    #
    # The +options+ are passed directly to the +belongs_to+ call, so this is where you declare +dependent+ etc.
    #
    # You can also declare namespaced types:
    #
    #   class Entry < ApplicationRecord
    #     delegated_type :entryable, types: %w[ Message Comment Access::NoticeMessage ], dependent: :destroy
    #   end
    #
    #   Entry.access_notice_messages
    #   entry.access_notice_message
    #   entry.access_notice_message?
    def delegated_type(role, types:, **options)
      belongs_to role, options.delete(:scope), **options.merge(polymorphic: true)
      define_delegated_type_methods role, types: types
    end

    private
      def define_delegated_type_methods(role, types:)
        role_type  = "#{role}_type"
        role_id    = "#{role}_id"
        role_class = "#{role}_class"

        define_method role_class do
          public_send(role_type).constantize
        end

        define_method "#{role}_name" do
          public_send(role_class).model_name.singular.inquiry
        end

        types.each do |type|
          scope_name = type.tableize.gsub("/", "_")
          singular   = scope_name.singularize
          query      = "#{singular}?"

          scope scope_name, -> { where(role_type => type) }

          define_method query do
            public_send(role_type) == type
          end

          define_method singular do
            public_send(role) if public_send(query)
          end

          define_method "#{singular}_id" do
            public_send(role_id) if public_send(query)
          end
        end
      end
  end
end
