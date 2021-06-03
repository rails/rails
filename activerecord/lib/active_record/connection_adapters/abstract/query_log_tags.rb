# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors_per_thread"

module ActiveRecord
  module ConnectionAdapters
    module QueryLogTags
      extend ActiveSupport::Concern
      included do
        mattr_accessor :prepend_comment, default: false
      end

      module ClassMethods
        def prepend_execution_methods # :nodoc:
          descendants.each do |klass|
            # Prepend execution methods for edge descendants of AbstractAdapter
            klass.prepend(ExecutionMethods) if klass.descendants.empty?
          end
        end

        def add_query_log_tags_to_sql(sql) # :nodoc:
          return sql unless QueryLogTagsContext.tags_available?
          comments = [QueryLogTagsContext.comment, QueryLogTagsContext.inline_comment].compact
          comments.each do |comment|
            if comment.present? && !sql.include?(comment)
              sql = if prepend_comment
                "#{comment} #{sql}"
              else
                "#{sql} #{comment}"
              end
            end
          end
          sql
        end
      end

      module ExecutionMethods
        def execute(sql, *args, **kwargs)
          super(self.class.add_query_log_tags_to_sql(sql), *args, **kwargs)
        end

        def exec_query(sql, *args, **kwargs)
          super(self.class.add_query_log_tags_to_sql(sql), *args, **kwargs)
        end
      end

      # Maintains a user-defined context for all queries and constructs an SQL comment by
      # calling methods listed in +components+
      #
      # Additional information can be added to the context to be referenced by methods
      # defined in framework or application initializers.
      #
      # To add new comment components, define class methods on +QueryLogTagsContext+ in
      # your application.
      #
      #    module ActiveRecord::ConnectionAdapters::QueryLogTags::QueryLogTagsContext
      #      class << self
      #        def custom_component
      #          "custom value"
      #        end
      #      end
      #    end
      #    ActiveRecord::ConnectionAdapters::QueryLogTags::QueryLogTagsContext.components = []:custom_component]
      #    ActiveRecord::ConnectionAdapters::QueryLogTags::QueryLogTagsContext.comment
      #    # /*custom_component:custom value*/
      #
      # Default components available for use:
      #
      # * +application+
      # * +pid+
      # * +socket+
      # * +db_host+
      # * +database+
      # * +line+ (reported via BacktraceCleaner)
      #
      # _When included in Rails, ActiveController and ActiveJob components are also defined._
      #
      # * +controller+
      # * +action+
      # * +job+
      #
      # If required due to log truncation, comments can be prepended to the query instead:
      #
      #    ActiveRecord::ConnectionAdapters::QueryLogTags.prepend_comment = true


      module QueryLogTagsContext
        mattr_accessor :components, instance_accessor: false, default: [:application]
        mattr_accessor :cache_query_log_tags, instance_accessor: false, default: true
        mattr_accessor :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new
        thread_mattr_accessor :cached_comment, instance_accessor: false

        class << self
          # Updates the context used to construct the query log tags.
          # Resets the cached comment if <tt>cache_query_log_tags</tt> is +true+.
          def update(**options)
            context.merge!(**options.symbolize_keys)
            self.cached_comment = nil
          end

          def tags_available?
            components.present? || inline_annotations.present?
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
            else
              ""
            end
          end

          # Returns a +String+ containing any inline comments from +with_annotation+.
          def inline_comment
            return nil unless inline_annotations.present?
            "/*#{escape_sql_comment(inline_tag_content)}*/"
          end

          # Manually clear the comment cache.
          def clear_comment_cache!
            self.cached_comment = nil
          end

          # Annotate any query within `&block`. Can be nested.
          def with_annotation(comment, &block)
            self.inline_annotations.push(comment)
            block.call if block.present?
          ensure
            self.inline_annotations.pop
          end

          # Return the set of active inline annotations from +with_annotation+.
          def inline_annotations
            context[:inline_annotations] ||= []
          end

          # QueryLogTags +component+ methods

          # Set during Rails boot in lib/active_record/railtie.rb
          def application # :nodoc:
            context[:application_name]
          end

          def pid # :nodoc:
            Process.pid
          end

          def connection_config # :nodoc:
            ActiveRecord::Base.connection_db_config
          end

          def socket # :nodoc:
            connection_config.socket
          end

          def db_host # :nodoc:
            connection_config.host
          end

          def database # :nodoc:
            connection_config.database
          end

          def line # :nodoc:
            backtrace_cleaner.add_silencer { |line| line.match?(/lib\/active_(record|support)/) }
            backtrace_cleaner.clean(caller.lazy).first
          end

          private
            def context
              Thread.current[:active_record_query_log_tags_context] ||= {}
            end

            def escape_sql_comment(content)
              content.to_s.gsub(%r{ (/ (?: | \g<1>) \*) \+? \s* | \s* (\* (?: | \g<2>) /) }x, "")
            end

            def tag_content
              components.filter_map do |c|
                if value = send(c)
                  "#{c}:#{value}"
                end
              end.join(",")
            end

            def inline_tag_content
              inline_annotations.join
            end
        end
      end
      delegate :cache_query_log_tags, to: QueryLogTagsContext
    end
  end
end
