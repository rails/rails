# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Named \Scopes
  module Scoping
    module Named
      extend ActiveSupport::Concern

      module ClassMethods
        # Returns an ActiveRecord::Relation scope object.
        #
        #   posts = Post.all
        #   posts.size # Fires "select count(*) from  posts" and returns the count
        #   posts.each {|p| puts p.name } # Fires "select * from posts" and loads post objects
        #
        #   fruits = Fruit.all
        #   fruits = fruits.where(color: 'red') if options[:red_only]
        #   fruits = fruits.limit(10) if limited?
        #
        # You can define a scope that applies to all finders using
        # {default_scope}[rdoc-ref:Scoping::Default::ClassMethods#default_scope].
        def all(all_queries: nil)
          scope = current_scope

          if scope
            if self == scope.model
              scope.clone
            else
              relation.merge!(scope)
            end
          else
            default_scoped(all_queries: all_queries)
          end
        end

        def scope_for_association(scope = relation) # :nodoc:
          if current_scope&.empty_scope?
            scope
          else
            default_scoped(scope)
          end
        end

        # Returns a scope for the model with default scopes.
        def default_scoped(scope = relation, all_queries: nil)
          build_default_scope(scope, all_queries: all_queries) || scope
        end

        def default_extensions # :nodoc:
          if scope = scope_for_association || build_default_scope
            scope.extensions
          else
            []
          end
        end

        # Adds a class method for retrieving and querying objects.
        # The method is intended to return an ActiveRecord::Relation
        # object, which is composable with other scopes.
        # If it returns +nil+ or +false+, an
        # {all}[rdoc-ref:Scoping::Named::ClassMethods#all] scope is returned instead.
        #
        # A \scope represents a narrowing of a database query, such as
        # <tt>where(color: :red).select('shirts.*').includes(:washing_instructions)</tt>.
        #
        #   class Shirt < ActiveRecord::Base
        #     scope :red, -> { where(color: 'red') }
        #     scope :dry_clean_only, -> { joins(:washing_instructions).where('washing_instructions.dry_clean_only = ?', true) }
        #   end
        #
        # The above calls to #scope define class methods <tt>Shirt.red</tt> and
        # <tt>Shirt.dry_clean_only</tt>. <tt>Shirt.red</tt>, in effect,
        # represents the query <tt>Shirt.where(color: 'red')</tt>.
        #
        # Note that this is simply 'syntactic sugar' for defining an actual
        # class method:
        #
        #   class Shirt < ActiveRecord::Base
        #     def self.red
        #       where(color: 'red')
        #     end
        #   end
        #
        # Unlike <tt>Shirt.find(...)</tt>, however, the object returned by
        # <tt>Shirt.red</tt> is not an Array but an ActiveRecord::Relation,
        # which is composable with other scopes; it resembles the association object
        # constructed by a {has_many}[rdoc-ref:Associations::ClassMethods#has_many]
        # declaration. For instance, you can invoke <tt>Shirt.red.first</tt>, <tt>Shirt.red.count</tt>,
        # <tt>Shirt.red.where(size: 'small')</tt>. Also, just as with the
        # association objects, named \scopes act like an Array, implementing
        # Enumerable; <tt>Shirt.red.each(&block)</tt>, <tt>Shirt.red.first</tt>,
        # and <tt>Shirt.red.inject(memo, &block)</tt> all behave as if
        # <tt>Shirt.red</tt> really was an array.
        #
        # These named \scopes are composable. For instance,
        # <tt>Shirt.red.dry_clean_only</tt> will produce all shirts that are
        # both red and dry clean only. Nested finds and calculations also work
        # with these compositions: <tt>Shirt.red.dry_clean_only.count</tt>
        # returns the number of garments for which these criteria obtain.
        # Similarly with <tt>Shirt.red.dry_clean_only.average(:thread_count)</tt>.
        #
        # All scopes are available as class methods on the ActiveRecord::Base
        # descendant upon which the \scopes were defined. But they are also
        # available to {has_many}[rdoc-ref:Associations::ClassMethods#has_many]
        # associations. If,
        #
        #   class Person < ActiveRecord::Base
        #     has_many :shirts
        #   end
        #
        # then <tt>elton.shirts.red.dry_clean_only</tt> will return all of
        # Elton's red, dry clean only shirts.
        #
        # \Named scopes can also have extensions, just as with
        # {has_many}[rdoc-ref:Associations::ClassMethods#has_many] declarations:
        #
        #   class Shirt < ActiveRecord::Base
        #     scope :red, -> { where(color: 'red') } do
        #       def dom_id
        #         'red_shirts'
        #       end
        #     end
        #   end
        #
        # Scopes can also be used while creating/building a record.
        #
        #   class Article < ActiveRecord::Base
        #     scope :published, -> { where(published: true) }
        #   end
        #
        #   Article.published.new.published    # => true
        #   Article.published.create.published # => true
        #
        # \Class methods on your model are automatically available
        # on scopes. Assuming the following setup:
        #
        #   class Article < ActiveRecord::Base
        #     scope :published, -> { where(published: true) }
        #     scope :featured, -> { where(featured: true) }
        #
        #     def self.latest_article
        #       order('published_at desc').first
        #     end
        #
        #     def self.titles
        #       pluck(:title)
        #     end
        #   end
        #
        # We are able to call the methods like this:
        #
        #   Article.published.featured.latest_article
        #   Article.featured.titles
        def scope(name, body, &block)
          unless body.respond_to?(:call)
            raise ArgumentError, "The scope body needs to be callable."
          end

          if dangerous_class_method?(name)
            raise ArgumentError, "You tried to define a scope named \"#{name}\" " \
              "on the model \"#{self.name}\", but Active Record already defined " \
              "a class method with the same name."
          end

          if method_defined_within?(name, Relation)
            raise ArgumentError, "You tried to define a scope named \"#{name}\" " \
              "on the model \"#{self.name}\", but ActiveRecord::Relation already defined " \
              "an instance method with the same name."
          end

          extension = Module.new(&block) if block

          if body.respond_to?(:to_proc)
            singleton_class.define_method(name) do |*args|
              scope = all._exec_scope(*args, &body)
              scope = scope.extending(extension) if extension
              scope
            end
          else
            singleton_class.define_method(name) do |*args|
              scope = body.call(*args) || all
              scope = scope.extending(extension) if extension
              scope
            end
          end
          singleton_class.send(:ruby2_keywords, name)

          generate_relation_method(name)
        end

        private
          def singleton_method_added(name)
            super
            # Most Kernel extends are both singleton and instance methods so
            # respond_to is a fast check, but we don't want to define methods
            # only on the module (ex. Module#name)
            generate_relation_method(name) if Kernel.respond_to?(name) && (Kernel.method_defined?(name) || Kernel.private_method_defined?(name)) && !ActiveRecord::Relation.method_defined?(name)
          end
      end
    end
  end
end
