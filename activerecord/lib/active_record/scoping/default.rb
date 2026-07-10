# frozen_string_literal: true

module ActiveRecord
  module Scoping
    class DefaultScope # :nodoc:
      attr_reader :scope, :all_queries, :name

      def initialize(scope, all_queries = nil, name = nil)
        @scope = ActiveSupport::Ractors.try_shareable_proc(scope)
        @all_queries = all_queries
        @name = name
        freeze
      end

      def named?
        !@name.nil?
      end
    end

    module Default
      extend ActiveSupport::Concern

      included do
        # Stores the default scope for the class.
        class_attribute :default_scopes, instance_writer: false, instance_predicate: false, default: [].freeze
      end

      module ClassMethods
        # Returns a scope for the model without the previously set scopes.
        #
        # When called with no arguments, +unscoped+ removes only unnamed default
        # scopes. Named default scopes (see #default_scope) are durable and
        # survive +unscoped+ unless explicitly listed by name.
        #
        #   class Post < ActiveRecord::Base
        #     belongs_to :user
        #
        #     def self.default_scope
        #       where(published: true)
        #     end
        #   end
        #
        #   class User < ActiveRecord::Base
        #     has_many :posts
        #   end
        #
        #   Post.all                                  # Fires "SELECT * FROM posts WHERE published = true"
        #   Post.unscoped.all                         # Fires "SELECT * FROM posts"
        #   Post.where(published: false).unscoped.all # Fires "SELECT * FROM posts"
        #   User.find(1).posts                        # Fires "SELECT * FROM posts WHERE published = true AND posts.user_id = 1"
        #   User.find(1).posts.unscoped               # Fires "SELECT * FROM posts"
        #
        # This method also accepts a block. All queries inside the block will
        # not use the previously set scopes.
        #
        #   Post.unscoped {
        #     Post.limit(10) # Fires "SELECT * FROM posts LIMIT 10"
        #   }
        #
        # When called with one or more names, +unscoped+ removes only the named
        # default scopes that match. Unnamed default scopes are preserved. An
        # unknown name raises an +ArgumentError+. To remove both a named scope
        # and the unnamed default scopes, chain a bare +unscoped+ call:
        #
        #   class Article < ActiveRecord::Base
        #     default_scope { where(visible: true) }
        #     default_scope :published, -> { where(published: true) }
        #     default_scope :rating, -> { where(rating: 'G') }
        #   end
        #
        #   Article.unscoped.all            # Only the unnamed scope is removed
        #   # SELECT * FROM articles WHERE published = true AND rating = 'G'
        #
        #   Article.unscoped(:published).all # Only :published is removed
        #   # SELECT * FROM articles WHERE visible = true AND rating = 'G'
        #
        #   Article.unscoped(:published, :rating).all # Both named scopes removed
        #   Article.unscoped(:published).unscoped(:rating).all # Equivalent
        #   # SELECT * FROM articles WHERE visible = true
        #
        #   Article.unscoped.unscoped(:published, :rating).all # Named and unnamed removed
        #   # SELECT * FROM articles
        def unscoped(*names, &block)
          unscoped_relation = if default_scope_override?
            raise ArgumentError, "Named default scopes cannot be unscoped when default_scope is defined as a default_scope method." if names.any?
            raw_relation
          elsif names.empty? && default_scopes.none?(&:named?)
            raw_relation
          else
            scopes_to_exclude = if names.empty?
              default_scopes.reject(&:named?)
            else
              named_default_scopes(names)
            end

            build_default_scope(excluded: scopes_to_exclude)
          end

          block_given? ? unscoped_relation.scoping(&block) : unscoped_relation
        end

        # Are there attributes associated with this scope?
        def scope_attributes? # :nodoc:
          super || default_scopes.any? || respond_to?(:default_scope)
        end

        # Checks if the model has any default scopes. If all_queries
        # is set to true, the method will check if there are any
        # default_scopes for the model  where +all_queries+ is true.
        def default_scopes?(all_queries: false)
          if all_queries
            self.default_scopes.any?(&:all_queries)
          else
            self.default_scopes.any?
          end
        end

        def build_unscoped_default_scope(unscoping, all_queries: nil) # :nodoc:
          names = []
          unscoped_defaults = false

          case unscoping
          when Array
            unscoping.each do |value|
              case value
              when true
                unscoped_defaults = true
              when Symbol, String
                names << value
              else
                raise ArgumentError, "Default scope unscoping values must be symbols, strings, or true."
              end
            end

            if names.empty? && !unscoped_defaults
              raise ArgumentError, "Default scope unscoping must include a default scope name or true."
            end
          when Symbol, String
            names << unscoping
          else
            unscoped_defaults = true
          end

          if default_scope_override?
            raise ArgumentError, "Named default scopes cannot be unscoped when default_scope is defined as a default_scope method." if names.any?
            raw_relation
          else
            excluded_default_scopes = []
            excluded_default_scopes |= named_default_scopes(names) if names.any?
            excluded_default_scopes |= default_scopes.reject(&:named?) if unscoped_defaults

            build_default_scope(raw_relation, all_queries: all_queries, excluded: excluded_default_scopes)
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
          #   Article.all
          #   # SELECT * FROM articles WHERE published = true
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
          #     default_scope -> { where(blog_id: 1) }, all_queries: true
          #   end
          #
          # Applying a default scope to all queries will ensure that records
          # are always queried by the additional conditions. Note that only
          # where clauses apply, as it does not make sense to add order to
          # queries that return a single object by primary key.
          #
          #   Article.find(1).destroy
          #   # DELETE ... FROM `articles` where ID = 1 AND blog_id = 1;
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
          #   Article.all
          #   # SELECT * FROM articles WHERE published = true AND rating = 'G'
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
          #
          # === Named default scopes
          #
          # A default scope can be given a name, making it durable. It will
          # not be removed by +unscoped+ unless explicitly referenced by name.
          #
          #   class Article < ActiveRecord::Base
          #     default_scope :published, -> { where(published: true) }
          #     default_scope :rating, -> { where(rating: 'G') }
          #   end
          #
          #   Article.all
          #   # SELECT * FROM articles WHERE published = true AND rating = 'G'
          #
          #   Article.unscoped.all # Named scopes are preserved
          #   # SELECT * FROM articles WHERE published = true AND rating = 'G'
          #
          #   Article.unscoped(:published).all # Only :published is removed
          #   # SELECT * FROM articles WHERE rating = 'G'
          #
          # See +unscoped+ for more details on removing named default scopes.
          def default_scope(name_or_scope = nil, scope = nil, all_queries: nil, &block) # :doc:
            if name_or_scope.is_a?(Symbol) || name_or_scope.is_a?(String)
              name = name_or_scope.to_sym
            else
              name = nil
              scope = name_or_scope
            end

            scope = block if block_given?

            if scope.is_a?(Relation) || !scope.respond_to?(:call)
              raise ArgumentError,
                "Support for calling #default_scope without a block is removed. For example instead " \
                "of `default_scope where(color: 'red')`, please use " \
                "`default_scope { where(color: 'red') }`. (Alternatively you can just redefine " \
                "self.default_scope.)"
            end

            default_scope = DefaultScope.new(scope, all_queries, name)

            self.default_scopes = [*default_scopes, default_scope].freeze
          end

          def build_default_scope(relation = raw_relation, all_queries: nil, excluded: [])
            return relation if abstract_class?

            if default_scope_override?
              # The user has defined their own default scope method, so call that
              evaluate_default_scope do
                relation.scoping { default_scope }
              end
            elsif default_scopes.any?
              already_excluded = current_scope&.excluded_default_scopes || []
              excluded_scopes = already_excluded | excluded
              scopes = default_scopes - excluded_scopes
              relation.excluded_default_scopes = excluded_scopes

              return relation if scopes.empty?

              evaluate_default_scope do
                scopes.inject(relation) do |combined_scope, scope_obj|
                  if execute_scope?(all_queries, scope_obj)
                    scope = scope_obj.scope.respond_to?(:to_proc) ? scope_obj.scope : scope_obj.scope.method(:call)

                    combined_scope.instance_exec(&scope) || combined_scope
                  else
                    combined_scope
                  end
                end
              end
            end || relation
          end

          # If all_queries is nil, only execute on select and insert queries.
          #
          # If all_queries is true, check if the default_scope object has
          # all_queries set, then execute on all queries; select, insert, update,
          # delete, and reload.
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

          def default_scope_override?
            !Base.is_a?(method(:default_scope).owner)
          end

          def named_default_scopes(names)
            names = names.map do |scope_name|
              unless scope_name.is_a?(Symbol) || scope_name.is_a?(String)
                raise ArgumentError, "Default scope names must be symbols or strings."
              end

              scope_name.to_sym
            end

            scopes = default_scopes.select { |scope| names.include?(scope.name) }
            unknown_names = names - scopes.map(&:name)

            if unknown_names.any?
              formatted_names = unknown_names.map { |scope_name| ":#{scope_name}" }.join(", ")
              raise ArgumentError, "Unknown default scope name(s) for #{name}: #{formatted_names}"
            end

            scopes
          end
      end
    end
  end
end
