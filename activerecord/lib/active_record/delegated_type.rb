# frozen_string_literal: true

require "active_support/core_ext/string/inquiry"

module ActiveRecord
  # = Delegated types
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
  #   # Schema: messages[ id, subject, body ]
  #   class Message < ApplicationRecord
  #     include Entryable
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
  #   Account.find(1).entries.order(created_at: :desc).limit(50)
  #
  # Which is exactly what you want when displaying both comments and messages together. The entry itself can
  # be rendered as its delegated type easily, like so:
  #
  #   # entries/_entry.html.erb
  #   <%= render "entries/entryables/#{entry.entryable_name}", entry: entry %>
  #
  #   # entries/entryables/_message.html.erb
  #   <div class="message">
  #     <div class="subject"><%= entry.message.subject %></div>
  #     <p><%= entry.message.body %></p>
  #     <i>Posted on <%= entry.created_at %> by <%= entry.creator.name %></i>
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
  #     delegate :title, to: :entryable
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
  # Now you can list a bunch of entries, call <tt>Entry#title</tt>, and polymorphism will provide you with the answer.
  #
  # == Nested \Attributes
  #
  # Enabling nested attributes on a delegated_type association allows you to
  # create the entry and message in one go:
  #
  #   class Entry < ApplicationRecord
  #     delegated_type :entryable, types: %w[ Message Comment ]
  #     accepts_nested_attributes_for :entryable
  #   end
  #
  #   params = { entry: { entryable_type: 'Message', entryable_attributes: { subject: 'Smiling' } } }
  #   entry = Entry.create(params[:entry])
  #   entry.entryable.id # => 2
  #   entry.entryable.subject # => 'Smiling'
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
    # You can also declare namespaced types:
    #
    #   class Entry < ApplicationRecord
    #     delegated_type :entryable, types: %w[ Message Comment Access::NoticeMessage ], dependent: :destroy
    #   end
    #
    #   Entry.access_notice_messages
    #   entry.access_notice_message
    #   entry.access_notice_message?
    #
    # === Options
    #
    # The +options+ are passed directly to the +belongs_to+ call, so this is where you declare +dependent+ etc.
    # The following options can be included to specialize the behavior of the delegated type convenience methods.
    #
    # [:foreign_key]
    #   Specify the foreign key used for the convenience methods. By default this is guessed to be the passed
    #   +role+ with an "_id" suffix. So a class that defines a
    #   <tt>delegated_type :entryable, types: %w[ Message Comment ]</tt> association will use "entryable_id" as
    #   the default <tt>:foreign_key</tt>.
    # [:foreign_type]
    #   Specify the column used to store the associated object's type. By default this is inferred to be the passed
    #   +role+ with a "_type" suffix. A class that defines a
    #   <tt>delegated_type :entryable, types: %w[ Message Comment ]</tt> association will use "entryable_type" as
    #   the default <tt>:foreign_type</tt>.
    # [:primary_key]
    #   Specify the method that returns the primary key of associated object used for the convenience methods.
    #   By default this is +id+.
    #
    # Option examples:
    #   class Entry < ApplicationRecord
    #     delegated_type :entryable, types: %w[ Message Comment ], primary_key: :uuid, foreign_key: :entryable_uuid
    #   end
    #
    #   Entry#message_uuid      # => returns entryable_uuid, when entryable_type == "Message", otherwise nil
    #   Entry#comment_uuid      # => returns entryable_uuid, when entryable_type == "Comment", otherwise nil
    def delegated_type(role, types:, **options)
      belongs_to role, options.delete(:scope), **options.merge(polymorphic: true)
      define_delegated_type_methods role, types: types, options: options
    end

    private
      def define_delegated_type_methods(role, types:, options:)
        primary_key = options[:primary_key] || "id"
        role_type = options[:foreign_type] || "#{role}_type"
        role_id   = options[:foreign_key] || "#{role}_id"

        define_method "#{role}_class" do
          public_send(role_type).constantize
        end

        define_method "#{role}_name" do
          public_send("#{role}_class").model_name.singular.inquiry
        end

        define_method "build_#{role}" do |*params|
          public_send("#{role}=", public_send("#{role}_class").new(*params))
        end

        types.each do |type|
          scope_name = type.tableize.tr("/", "_")
          singular   = scope_name.singularize
          query      = "#{singular}?"

          scope scope_name, -> { where(role_type => type) }

          define_method query do
            public_send(role_type) == type
          end

          define_method singular do
            public_send(role) if public_send(query)
          end

          define_method "#{singular}_#{primary_key}" do
            public_send(role_id) if public_send(query)
          end
        end
      end
  end
end
