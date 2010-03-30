require 'active_support/core_ext/array'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/object/singleton_class'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module NamedScope
    extend ActiveSupport::Concern

    module ClassMethods
      # Returns a relation if invoked without any arguments.
      #
      #   posts = Post.scoped
      #   posts.size # Fires "select count(*) from  posts" and returns the count
      #   posts.each {|p| puts p.name } # Fires "select * from posts" and loads post objects
      #
      # Returns an anonymous named scope if any options are supplied.
      #
      #   shirts = Shirt.scoped(:conditions => {:color => 'red'})
      #   shirts = shirts.scoped(:include => :washing_instructions)
      #
      # Anonymous \scopes tend to be useful when procedurally generating complex queries, where passing
      # intermediate values (scopes) around as first-class objects is convenient.
      #
      # You can define a scope that applies to all finders using ActiveRecord::Base.default_scope.
      def scoped(options = {}, &block)
        if options.present?
          Scope.init(self, options, &block)
        else
          current_scoped_methods ? unscoped.merge(current_scoped_methods) : unscoped.clone
        end
      end

      def scopes
        read_inheritable_attribute(:scopes) || write_inheritable_attribute(:scopes, {})
      end

      # Adds a class method for retrieving and querying objects. A scope represents a narrowing of a database query,
      # such as <tt>:conditions => {:color => :red}, :select => 'shirts.*', :include => :washing_instructions</tt>.
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :red, :conditions => {:color => 'red'}
      #     scope :dry_clean_only, :joins => :washing_instructions, :conditions => ['washing_instructions.dry_clean_only = ?', true]
      #   end
      #
      # The above calls to <tt>scope</tt> define class methods Shirt.red and Shirt.dry_clean_only. Shirt.red,
      # in effect, represents the query <tt>Shirt.find(:all, :conditions => {:color => 'red'})</tt>.
      #
      # Unlike <tt>Shirt.find(...)</tt>, however, the object returned by Shirt.red is not an Array; it resembles the association object
      # constructed by a <tt>has_many</tt> declaration. For instance, you can invoke <tt>Shirt.red.find(:first)</tt>, <tt>Shirt.red.count</tt>,
      # <tt>Shirt.red.find(:all, :conditions => {:size => 'small'})</tt>. Also, just
      # as with the association objects, named \scopes act like an Array, implementing Enumerable; <tt>Shirt.red.each(&block)</tt>,
      # <tt>Shirt.red.first</tt>, and <tt>Shirt.red.inject(memo, &block)</tt> all behave as if Shirt.red really was an Array.
      #
      # These named \scopes are composable. For instance, <tt>Shirt.red.dry_clean_only</tt> will produce all shirts that are both red and dry clean only.
      # Nested finds and calculations also work with these compositions: <tt>Shirt.red.dry_clean_only.count</tt> returns the number of garments
      # for which these criteria obtain. Similarly with <tt>Shirt.red.dry_clean_only.average(:thread_count)</tt>.
      #
      # All \scopes are available as class methods on the ActiveRecord::Base descendant upon which the \scopes were defined. But they are also available to
      # <tt>has_many</tt> associations. If,
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
      #     scope :colored, lambda { |color|
      #       { :conditions => { :color => color } }
      #     }
      #   end
      #
      # In this example, <tt>Shirt.colored('puce')</tt> finds all puce shirts.
      #
      # Named \scopes can also have extensions, just as with <tt>has_many</tt> declarations:
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :red, :conditions => {:color => 'red'} do
      #       def dom_id
      #         'red_shirts'
      #       end
      #     end
      #   end
      #
      #
      # For testing complex named \scopes, you can examine the scoping options using the
      # <tt>proxy_options</tt> method on the proxy itself.
      #
      #   class Shirt < ActiveRecord::Base
      #     scope :colored, lambda { |color|
      #       { :conditions => { :color => color } }
      #     }
      #   end
      #
      #   expected_options = { :conditions => { :colored => 'red' } }
      #   assert_equal expected_options, Shirt.colored('red').proxy_options
      def scope(name, options = {}, &block)
        name = name.to_sym

        if !scopes[name] && respond_to?(name, true)
          logger.warn "Creating scope :#{name}. " \
                      "Overwriting existing method #{self.name}.#{name}."
        end

        scopes[name] = lambda do |parent_scope, *args|
          Scope.init(parent_scope, case options
            when Hash, Relation
              options
            when Proc
              options.call(*args)
          end, &block)
        end
        singleton_class.instance_eval do
          define_method name do |*args|
            scopes[name].call(self, *args)
          end
        end
      end

      def named_scope(*args, &block)
        ActiveSupport::Deprecation.warn("Base.named_scope has been deprecated, please use Base.scope instead", caller)
        scope(*args, &block)
      end
    end

    class Scope < Relation
      attr_accessor :current_scoped_methods_when_defined

      delegate :scopes, :with_scope, :with_exclusive_scope, :scoped_methods, :scoped, :to => :klass

      def self.init(klass, options, &block)
        relation = new(klass, klass.arel_table)

        scope = if options.is_a?(Hash)
          klass.scoped.apply_finder_options(options.except(:extend))
        else
          options ? klass.scoped.merge(options) : klass.scoped
        end

        relation = relation.merge(scope)

        Array.wrap(options[:extend]).each {|extension| relation.send(:extend, extension) } if options.is_a?(Hash)
        relation.send(:extend, Module.new(&block)) if block_given?

        relation.current_scoped_methods_when_defined = klass.send(:current_scoped_methods)
        relation
      end

      def first(*args)
        if args.first.kind_of?(Integer) || (loaded? && !args.first.kind_of?(Hash))
          to_a.first(*args)
        else
          args.first.present? ? apply_finder_options(args.first).first : super
        end
      end

      def last(*args)
        if args.first.kind_of?(Integer) || (loaded? && !args.first.kind_of?(Hash))
          to_a.last(*args)
        else
          args.first.present? ? apply_finder_options(args.first).last : super
        end
      end

      def ==(other)
        case other
        when Scope
          to_sql == other.to_sql
        when Relation
          other == self
        when Array
          to_a == other.to_a
        end
      end

      private

      def method_missing(method, *args, &block)
        if klass.respond_to?(method)
          with_scope(self) do
            if current_scoped_methods_when_defined && !scoped_methods.include?(current_scoped_methods_when_defined) && !scopes.include?(method)
              with_scope(current_scoped_methods_when_defined) { klass.send(method, *args, &block) }
            else
              klass.send(method, *args, &block)
            end
          end
        else
          super
        end
      end

    end

  end
end
