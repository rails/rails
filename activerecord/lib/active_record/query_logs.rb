# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors_per_thread"

module ActiveRecord
  # = Active Record Query Logs
  #
  # Automatically tag SQL queries with runtime information.
  #
  # Default tags available for use:
  #
  # * +application+
  # * +pid+
  # * +socket+
  # * +db_host+
  # * +database+
  #
  # _Action Controller and Active Job tags are also defined when used in Rails:_
  #
  # * +controller+
  # * +action+
  # * +job+
  #
  # The tags used in a query can be configured directly:
  #
  #     ActiveRecord::QueryLogs.tags = [ :application, :controller, :action, :job ]
  #
  # or via Rails configuration:
  #
  #     config.active_record.query_log_tags = [ :application, :controller, :action, :job ]
  #
  # To add new comment tags, add a hash to the tags array containing the keys and values you
  # want to add to the comment. Dynamic content can be created by setting a proc or lambda value in a hash,
  # and can reference any value stored in the +context+ object.
  #
  # Example:
  #
  #    tags = [
  #      :application,
  #      {
  #        custom_tag: ->(context) { context[:controller].controller_name },
  #        custom_value: -> { Custom.value },
  #      }
  #    ]
  #    ActiveRecord::QueryLogs.tags = tags
  #
  # The QueryLogs +context+ can be manipulated via +update_context+ & +set_context+ methods.
  #
  # Direct updates to a context value:
  #
  #    ActiveRecord::QueryLogs.update_context(foo: Bar.new)
  #
  # Temporary updates limited to the execution of a block:
  #
  #    ActiveRecord::QueryLogs.set_context(foo: Bar.new) do
  #      posts = Post.all
  #    end
  #
  # Tag comments can be prepended to the query:
  #
  #    ActiveRecord::QueryLogs.prepend_comment = true
  #
  # For applications where the content will not change during the lifetime of
  # the request or job execution, the tags can be cached for reuse in every query:
  #
  #    ActiveRecord::QueryLogs.cache_query_log_tags = true
  #
  # This option can be set during application configuration or in a Rails initializer:
  #
  #    config.active_record.cache_query_log_tags = true
  module QueryLogs
    mattr_accessor :taggings, instance_accessor: false, default: {}
    mattr_accessor :tags, instance_accessor: false, default: [ :application ]
    mattr_accessor :prepend_comment, instance_accessor: false, default: false
    mattr_accessor :cache_query_log_tags, instance_accessor: false, default: false
    thread_mattr_accessor :cached_comment, instance_accessor: false

    class NullObject # :nodoc:
      def method_missing(method, *args, &block)
        NullObject.new
      end

      def nil?
        true
      end

      private
        def respond_to_missing?(method, include_private = false)
          true
        end
    end

    class << self
      # Updates the context used to construct tags in the SQL comment.
      # Resets the cached comment if <tt>cache_query_log_tags</tt> is +true+.
      def update_context(**options)
        context.merge!(**options.symbolize_keys)
        self.cached_comment = nil
      end

      # Updates the context used to construct tags in the SQL comment during
      # execution of the provided block. Resets the provided keys to their
      # previous value once the block exits.
      def set_context(**options)
        keys = options.keys
        previous_context = keys.zip(context.values_at(*keys)).to_h
        update_context(**options)
        yield if block_given?
      ensure
        update_context(**previous_context)
      end

      # Temporarily tag any query executed within `&block`. Can be nested.
      def with_tag(tag, &block)
        inline_tags.push(tag)
        yield if block_given?
      ensure
        inline_tags.pop
      end

      def call(sql) # :nodoc:
        parts = self.comments
        if prepend_comment
          parts << sql
        else
          parts.unshift(sql)
        end
        parts.join(" ")
      end

      private
        # Returns an array of comments which need to be added to the query, comprised
        # of configured and inline tags.
        def comments
          [ comment, inline_comment ].compact
        end

        # Returns an SQL comment +String+ containing the query log tags.
        # Sets and returns a cached comment if <tt>cache_query_log_tags</tt> is +true+.
        def comment
          if cache_query_log_tags
            self.cached_comment ||= uncached_comment
          else
            uncached_comment
          end
        end

        def uncached_comment
          content = tag_content
          if content.present?
            "/*#{escape_sql_comment(content)}*/"
          end
        end

        # Returns a +String+ containing any inline comments from +with_tag+.
        def inline_comment
          return nil unless inline_tags.present?
          "/*#{escape_sql_comment(inline_tag_content)}*/"
        end

        # Return the set of active inline tags from +with_tag+.
        def inline_tags
          if context[:inline_tags].nil?
            context[:inline_tags] = []
          else
            context[:inline_tags]
          end
        end

        def context
          Thread.current[:active_record_query_log_tags_context] ||= Hash.new { NullObject.new }
        end

        def escape_sql_comment(content)
          content.to_s.gsub(%r{ (/ (?: | \g<1>) \*) \+? \s* | \s* (\* (?: | \g<2>) /) }x, "")
        end

        def tag_content
          tags.flat_map { |i| [*i] }.filter_map do |tag|
            key, handler = tag
            handler ||= taggings[key]

            val = if handler.nil?
              context[key]
            elsif handler.respond_to?(:call)
              if handler.arity == 0
                handler.call
              else
                handler.call(context)
              end
            else
              handler
            end
            "#{key}:#{val}" unless val.nil?
          end.join(",")
        end

        def inline_tag_content
          inline_tags.join
        end
    end
  end
end
