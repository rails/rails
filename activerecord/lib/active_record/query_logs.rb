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
  # Escaping is performed on the string returned, however untrusted user input should not be used.
  #
  # Example:
  #
  #    tags = [
  #      :application,
  #      {
  #        custom_tag: ->(context) { context[:controller]&.controller_name },
  #        custom_value: -> { Custom.value },
  #      }
  #    ]
  #    ActiveRecord::QueryLogs.tags = tags
  #
  # The QueryLogs +context+ can be manipulated via the +ActiveSupport::ExecutionContext.set+ method.
  #
  # Temporary updates limited to the execution of a block:
  #
  #    ActiveSupport::ExecutionContext.set(foo: Bar.new) do
  #      posts = Post.all
  #    end
  #
  # Direct updates to a context value:
  #
  #    ActiveSupport::ExecutionContext[:foo] = Bar.new
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
      def call(sql) # :nodoc:
        if prepend_comment
          "#{self.comment} #{sql}"
        else
          "#{sql} #{self.comment}"
        end.strip
      end

      def clear_cache # :nodoc:
        self.cached_comment = nil
      end

      ActiveSupport::ExecutionContext.after_change { ActiveRecord::QueryLogs.clear_cache }

      private
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

        def escape_sql_comment(content)
          # Sanitize a string to appear within a SQL comment
          # For compatibility, this also surrounding "/*+", "/*", and "*/"
          # charcacters, possibly with single surrounding space.
          # Then follows that by replacing any internal "*/" or "/ *" with
          # "* /" or "/ *"
          comment = content.to_s.dup
          comment.gsub!(%r{\A\s*/\*\+?\s?|\s?\*/\s*\Z}, "")
          comment.gsub!("*/", "* /")
          comment.gsub!("/*", "/ *")
          comment
        end

        def tag_content
          context = ActiveSupport::ExecutionContext.to_h

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
    end
  end
end
