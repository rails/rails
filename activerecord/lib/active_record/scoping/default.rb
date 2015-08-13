module ActiveRecord
  module Scoping
    module Default
      extend ActiveSupport::Concern

      included do
        # Stores the default scope for the class.
        class_attribute :default_scopes, instance_writer: false, instance_predicate: false

        self.default_scopes = []
      end

      module ClassMethods
        # Returns a scope for the model without the previously set scopes.
        #
        #   class Post < ActiveRecord::Base
        #     def self.default_scope
        #       where published: true
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

        def before_remove_const #:nodoc:
          self.current_scope = nil
        end

        protected

        # Use this macro in your model to set a default scope for all operations on
        # the model.
        #
        #   class Article < ActiveRecord::Base
        #     default_scope { where(published: true) }
        #   end
        #
        #   Article.all # => SELECT * FROM articles WHERE published = true
        #
        # The +default_scope+ is also applied while creating/building a record.
        # It is not applied while updating a record.
        #
        #   Article.new.published    # => true
        #   Article.create.published # => true
        #
        # (You can also pass any object which responds to +call+ to the
        # +default_scope+ macro, and it will be called when building the
        # default scope.)
        #
        # If you use multiple +default_scope+ declarations in your model then
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
        # parent or module defines a +default_scope+ and the child or including
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
        def default_scope(scope = nil)
          scope = Proc.new if block_given?

          if scope.is_a?(Relation) || !scope.respond_to?(:call)
            raise ArgumentError,
              "Support for calling #default_scope without a block is removed. For example instead " \
              "of `default_scope where(color: 'red')`, please use " \
              "`default_scope { where(color: 'red') }`. (Alternatively you can just redefine " \
              "self.default_scope.)"
          end

          self.default_scopes += [scope]
        end

        def build_default_scope(base_rel = relation) # :nodoc:
          return if abstract_class?
          if !Base.is_a?(method(:default_scope).owner)
            # The user has defined their own default scope method, so call that
            evaluate_default_scope { default_scope }
          elsif default_scopes.any?
            evaluate_default_scope do
              default_scopes.inject(base_rel) do |default_scope, scope|
                default_scope.merge(base_rel.scoping { scope.call })
              end
            end
          end
        end

        def ignore_default_scope? # :nodoc:
          ScopeRegistry.value_for(:ignore_default_scope, self)
        end

        def ignore_default_scope=(ignore) # :nodoc:
          ScopeRegistry.set_value_for(:ignore_default_scope, self, ignore)
        end

        # The ignore_default_scope flag is used to prevent an infinite recursion
        # situation where a default scope references a scope which has a default
        # scope which references a scope...
        def evaluate_default_scope # :nodoc:
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
