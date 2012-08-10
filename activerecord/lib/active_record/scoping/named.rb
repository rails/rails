require 'active_support/core_ext/array'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/kernel/singleton_class'

module ActiveRecord
  # = Active Record Named \Scopes
  module Scoping
    module Named
      extend ActiveSupport::Concern

      module ClassMethods
        # Returns an <tt>ActiveRecord::Relation</tt> scope object.
        #
        #   posts = Post.all
        #   posts.size # Fires "select count(*) from  posts" and returns the count
        #   posts.each {|p| puts p.name } # Fires "select * from posts" and loads post objects
        #
        #   fruits = Fruit.all
        #   fruits = fruits.where(:color => 'red') if options[:red_only]
        #   fruits = fruits.limit(10) if limited?
        #
        # You can define a \scope that applies to all finders using
        # ActiveRecord::Base.default_scope.
        def all
          if current_scope
            current_scope.clone
          else
            scope = relation
            scope.default_scoped = true
            scope
          end
        end

        ##
        # Collects attributes from scopes that should be applied when creating
        # an AR instance for the particular class this is called on.
        def scope_attributes # :nodoc:
          if current_scope
            current_scope.scope_for_create
          else
            scope = relation
            scope.default_scoped = true
            scope.scope_for_create
          end
        end

        ##
        # Are there default attributes associated with this scope?
        def scope_attributes? # :nodoc:
          current_scope || default_scopes.any?
        end

        # Adds a class method for retrieving and querying objects. A \scope represents a narrowing of a database query,
        # such as <tt>where(:color => :red).select('shirts.*').includes(:washing_instructions)</tt>.
        #
        #   class Shirt < ActiveRecord::Base
        #     scope :red, where(:color => 'red')
        #     scope :dry_clean_only, joins(:washing_instructions).where('washing_instructions.dry_clean_only = ?', true)
        #   end
        #
        # The above calls to <tt>scope</tt> define class methods Shirt.red and Shirt.dry_clean_only. Shirt.red,
        # in effect, represents the query <tt>Shirt.where(:color => 'red')</tt>.
        #
        # Note that this is simply 'syntactic sugar' for defining an actual class method:
        #
        #   class Shirt < ActiveRecord::Base
        #     def self.red
        #       where(:color => 'red')
        #     end
        #   end
        #
        # Unlike <tt>Shirt.find(...)</tt>, however, the object returned by Shirt.red is not an Array; it
        # resembles the association object constructed by a <tt>has_many</tt> declaration. For instance,
        # you can invoke <tt>Shirt.red.first</tt>, <tt>Shirt.red.count</tt>, <tt>Shirt.red.where(:size => 'small')</tt>.
        # Also, just as with the association objects, named \scopes act like an Array, implementing Enumerable;
        # <tt>Shirt.red.each(&block)</tt>, <tt>Shirt.red.first</tt>, and <tt>Shirt.red.inject(memo, &block)</tt>
        # all behave as if Shirt.red really was an Array.
        #
        # These named \scopes are composable. For instance, <tt>Shirt.red.dry_clean_only</tt> will produce
        # all shirts that are both red and dry clean only.
        # Nested finds and calculations also work with these compositions: <tt>Shirt.red.dry_clean_only.count</tt>
        # returns the number of garments for which these criteria obtain. Similarly with
        # <tt>Shirt.red.dry_clean_only.average(:thread_count)</tt>.
        #
        # All \scopes are available as class methods on the ActiveRecord::Base descendant upon which
        # the \scopes were defined. But they are also available to <tt>has_many</tt> associations. If,
        #
        #   class Person < ActiveRecord::Base
        #     has_many :shirts
        #   end
        #
        # then <tt>elton.shirts.red.dry_clean_only</tt> will return all of Elton's red, dry clean
        # only shirts.
        #
        # Named \scopes can also be procedural:
        #
        #   class Shirt < ActiveRecord::Base
        #     scope :colored, lambda { |color| where(:color => color) }
        #   end
        #
        # In this example, <tt>Shirt.colored('puce')</tt> finds all puce shirts.
        #
        # On Ruby 1.9 you can use the 'stabby lambda' syntax:
        #
        #   scope :colored, ->(color) { where(:color => color) }
        #
        # Note that scopes defined with \scope will be evaluated when they are defined, rather than
        # when they are used. For example, the following would be incorrect:
        #
        #   class Post < ActiveRecord::Base
        #     scope :recent, where('published_at >= ?', Time.current - 1.week)
        #   end
        #
        # The example above would be 'frozen' to the <tt>Time.current</tt> value when the <tt>Post</tt>
        # class was defined, and so the resultant SQL query would always be the same. The correct
        # way to do this would be via a lambda, which will re-evaluate the scope each time
        # it is called:
        #
        #   class Post < ActiveRecord::Base
        #     scope :recent, lambda { where('published_at >= ?', Time.current - 1.week) }
        #   end
        #
        # Named \scopes can also have extensions, just as with <tt>has_many</tt> declarations:
        #
        #   class Shirt < ActiveRecord::Base
        #     scope :red, where(:color => 'red') do
        #       def dom_id
        #         'red_shirts'
        #       end
        #     end
        #   end
        #
        # Scopes can also be used while creating/building a record.
        #
        #   class Article < ActiveRecord::Base
        #     scope :published, where(:published => true)
        #   end
        #
        #   Article.published.new.published    # => true
        #   Article.published.create.published # => true
        #
        # Class methods on your model are automatically available
        # on scopes. Assuming the following setup:
        #
        #   class Article < ActiveRecord::Base
        #     scope :published, where(:published => true)
        #     scope :featured, where(:featured => true)
        #
        #     def self.latest_article
        #       order('published_at desc').first
        #     end
        #
        #     def self.titles
        #       map(&:title)
        #     end
        #
        #   end
        #
        # We are able to call the methods like this:
        #
        #   Article.published.featured.latest_article
        #   Article.featured.titles

        def scope(name, body, &block)
          extension = Module.new(&block) if block

          # Check body.is_a?(Relation) to prevent the relation actually being
          # loaded by respond_to?
          if body.is_a?(Relation) || !body.respond_to?(:call)
            ActiveSupport::Deprecation.warn(
              "Using #scope without passing a callable object is deprecated. For " \
              "example `scope :red, where(color: 'red')` should be changed to " \
              "`scope :red, -> { where(color: 'red') }`. There are numerous gotchas " \
              "in the former usage and it makes the implementation more complicated " \
              "and buggy. (If you prefer, you can just define a class method named " \
              "`self.red`.)"
            )
          end

          singleton_class.send(:define_method, name) do |*args|
            options  = body.respond_to?(:call) ? unscoped { body.call(*args) } : body
            relation = all.merge(options)

            extension ? relation.extending(extension) : relation
          end
        end
      end
    end
  end
end
