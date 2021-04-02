# frozen_string_literal: true

module ActiveRecord
  module Scoping
    class DefaultScope # :nodoc:
      attr_reader :scope, :all_queries

      def initialize(scope, all_queries = nil)
        @scope = scope
        @all_queries = all_queries
      end
    end

    module Default
      extend ActiveSupport::Concern

      included do
        # Stores the default scope for the class.
        class_attribute :default_scopes, instance_writer: false, instance_predicate: false, default: []
        class_attribute :default_scope_override, instance_writer: false, instance_predicate: false, default: nil
      end

      module ClassMethods
        # Returns a scope for the model without the previously set scopes.
        #
        #   class Post < ActiveRecord::Base
        #     def self.default_scope
        #       where(published: true)
        #     end
        #   end
        #
        #   Post.all                                  # Fires "SELECT * FROM posts WHERE published = true"
        #   Post.unscoped.all                         # Fires "SELECT * FROM posts"
        #   Post.where(published: false).unscoped.all # Fires "SELECT * FROM posts"
        #
        # This method also accepts a block. All queries inside the block will
        # not use the previously set scopes.
        #
        #   Post.unscoped {
        #     Post.limit(10) # Fires "SELECT * FROM posts LIMIT 10"
        #   }
        def unscoped
          block_given? ? relation.scoping { yield } : relation
        end

        # Are there attributes associated with this scope?
        def scope_attributes? # :nodoc:
          super || default_scopes.any? || respond_to?(:default_scope)
        end

        def before_remove_const #:nodoc:
          self.current_scope = nil
        end

        # Checks if the model has any default scopes. If all_queries
        # is set to true, the method will check if there are any
        # default_scopes for the model  where +all_queries+ is true.
        def default_scopes?(all_queries: false)
          if all_queries
            self.default_scopes.map(&:all_queries).include?(true)
          else
            self.default_scopes.any?
          end
        end

        private
          # Use this macro in your model to set a default scope for all operations on
          # the model.
          #
          #   class Article < ActiveRecord::Base
          #     default_scope { where(published: true) }
          #   end
          #
          #   Article.all # => SELECT * FROM articles WHERE published = true
          #
          # The #default_scope is also applied while creating/building a record.
          # It is not applied while updating or deleting a record.
          #
          #   Article.new.published    # => true
          #   Article.create.published # => true
          #
          # To apply a #default_scope when updating or deleting a record, add
          # <tt>all_queries: true</tt>:
          #
          #   class Article < ActiveRecord::Base
          #     default_scope { where(blog_id: 1) }, all_queries: true
          #   end
          #
          # Applying a default scope to all queries will ensure that records
          # are always queried by the additional conditions. Note that only
          # where clauses apply, as it does not make sense to add order to
          # queries that return a single object by primary key.
          #
          #   Article.find(1).destroy
          #   => DELETE ... FROM `articles` where ID = 1 AND blog_id = 1;
          #
          # (You can also pass any object which responds to +call+ to the
          # +default_scope+ macro, and it will be called when building the
          # default scope.)
          #
          # If you use multiple #default_scope declarations in your model then
          # they will be merged together:
          #
          #   class Article < ActiveRecord::Base
          #     default_scope { where(published: true) }
          #     default_scope { where(rating: 'G') }
          #   end
          #
          #   Article.all # => SELECT * FROM articles WHERE published = true AND rating = 'G'
          #
          # This is also the case with inheritance and module includes where the
          # parent or module defines a #default_scope and the child or including
          # class defines a second one.
          #
          # If you need to do more complex things with a default scope, you can
          # alternatively define it as a class method:
          #
          #   class Article < ActiveRecord::Base
          #     def self.default_scope
          #       # Should return a scope, you can call 'super' here etc.
          #     end
          #   end
          def default_scope(scope = nil, all_queries: nil, &block) # :doc:
            scope = block if block_given?

            if scope.is_a?(Relation) || !scope.respond_to?(:call)
              raise ArgumentError,
                "Support for calling #default_scope without a block is removed. For example instead " \
                "of `default_scope where(color: 'red')`, please use " \
                "`default_scope { where(color: 'red') }`. (Alternatively you can just redefine " \
                "self.default_scope.)"
            end

            default_scope = DefaultScope.new(scope, all_queries)

            self.default_scopes += [default_scope]
          end

          def build_default_scope(relation = relation(), all_queries: nil)
            return if abstract_class?

            if default_scope_override.nil?
              self.default_scope_override = !Base.is_a?(method(:default_scope).owner)
            end

            if default_scope_override
              # The user has defined their own default scope method, so call that
              evaluate_default_scope do
                if scope = default_scope
                  relation.merge!(scope)
                end
              end
            elsif default_scopes.any?
              evaluate_default_scope do
                default_scopes.inject(relation) do |default_scope, scope_obj|
                  if execute_scope?(all_queries, scope_obj)
                    scope = scope_obj.scope.respond_to?(:to_proc) ? scope_obj.scope : scope_obj.scope.method(:call)

                    default_scope.instance_exec(&scope) || default_scope
                  end
                end
              end
            end
          end

          # If all_queries is nil, only execute on select and insert queries.
          #
          # If all_queries is true, check if the default_scope object has
          # all_queries set, then execute on all queries; select, insert, update
          # and delete.
          def execute_scope?(all_queries, default_scope_obj)
            all_queries.nil? || all_queries && default_scope_obj.all_queries
          end

          def ignore_default_scope?
            ScopeRegistry.ignore_default_scope(base_class)
          end

          def ignore_default_scope=(ignore)
            ScopeRegistry.set_ignore_default_scope(base_class, ignore)
          end

          # The ignore_default_scope flag is used to prevent an infinite recursion
          # situation where a default scope references a scope which has a default
          # scope which references a scope...
          def evaluate_default_scope
            return if ignore_default_scope?

            begin
              self.ignore_default_scope = true
              yield
            ensure
              self.ignore_default_scope = false
            end
          end
      end
    end
  end
end
