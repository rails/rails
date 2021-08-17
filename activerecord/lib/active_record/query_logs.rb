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
  #      { custom_tag: -> { context[:controller].controller_name } }
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

    class << self
      # Updates the context used to construct tags in the SQL comment.
      # Resets the cached comment if <tt>cache_query_log_tags</tt> is +true+.
      def update_context(**options)
        context.merge!(**options.symbolize_keys)
        self.cached_comment = nil
      end

      # Updates the context used to construct tags in the SQL comment during
      # execution of the provided block. Resets provided values to nil after
      # the block is executed.
      def set_context(**options)
        update_context(**options)
        yield if block_given?
      ensure
        update_context(**options.transform_values! { nil })
      end

      # Temporarily tag any query executed within `&block`. Can be nested.
      def with_tag(tag, &block)
        inline_tags.push(tag)
        yield if block_given?
      ensure
        inline_tags.pop
      end

      def add_query_log_tags_to_sql(sql) # :nodoc:
        comments.each do |comment|
          unless sql.include?(comment)
            sql = prepend_comment ? "#{comment} #{sql}" : "#{sql} #{comment}"
          end
        end
        sql
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
          context[:inline_tags] ||= []
        end

        def context
          Thread.current[:active_record_query_log_tags_context] ||= {}
        end

        def escape_sql_comment(content)
          content.to_s.gsub(%r{ (/ (?: | \g<1>) \*) \+? \s* | \s* (\* (?: | \g<2>) /) }x, "")
        end

        def tag_content
          tags.flat_map { |i| [*i] }.filter_map do |tag|
            key, value_input = tag
            val = case value_input
                  when nil then tag_value(key) if taggings.has_key? key
                  when Proc then instance_exec(&value_input)
                  else value_input
            end
            "#{key}:#{val}" unless val.nil?
          end.join(",")
        end

        def tag_value(key)
          value = taggings[key]

          if value.respond_to?(:call)
            instance_exec(&taggings[key])
          else
            value
          end
        end

        def inline_tag_content
          inline_tags.join
        end
    end

    module ExecutionMethods
      def execute(sql, *args, **kwargs)
        super(ActiveRecord::QueryLogs.add_query_log_tags_to_sql(sql), *args, **kwargs)
      end

      def exec_query(sql, *args, **kwargs)
        super(ActiveRecord::QueryLogs.add_query_log_tags_to_sql(sql), *args, **kwargs)
      end
    end
  end
end
