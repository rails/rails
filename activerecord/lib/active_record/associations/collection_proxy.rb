require 'active_support/deprecation'

module ActiveRecord
  module Associations
    AssociationCollection = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
      'ActiveRecord::Associations::AssociationCollection',
      'ActiveRecord::Associations::CollectionProxy'
    )

    # Association proxies in Active Record are middlemen between the object that
    # holds the association, known as the <tt>@owner</tt>, and the actual associated
    # object, known as the <tt>@target</tt>. The kind of association any proxy is
    # about is available in <tt>@reflection</tt>. That's an instance of the class
    # ActiveRecord::Reflection::AssociationReflection.
    #
    # For example, given
    #
    #   class Blog < ActiveRecord::Base
    #     has_many :posts
    #   end
    #
    #   blog = Blog.first
    #
    # the association proxy in <tt>blog.posts</tt> has the object in +blog+ as
    # <tt>@owner</tt>, the collection of its posts as <tt>@target</tt>, and
    # the <tt>@reflection</tt> object represents a <tt>:has_many</tt> macro.
    #
    # This class has most of the basic instance methods removed, and delegates
    # unknown methods to <tt>@target</tt> via <tt>method_missing</tt>. As a
    # corner case, it even removes the +class+ method and that's why you get
    #
    #   blog.posts.class # => Array
    #
    # though the object behind <tt>blog.posts</tt> is not an Array, but an
    # ActiveRecord::Associations::HasManyAssociation.
    #
    # The <tt>@target</tt> object is not \loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class CollectionProxy # :nodoc:
      alias :proxy_extend :extend

      instance_methods.each { |m| undef_method m unless m.to_s =~ /^(?:nil\?|send|object_id|to_a)$|^__|^respond_to|proxy_/ }

      delegate :group, :order, :limit, :joins, :where, :preload, :eager_load, :includes, :from,
               :lock, :readonly, :having, :to => :scoped

      delegate :target, :load_target, :loaded?, :scoped,
               :to => :@association

      delegate :select, :find, :first, :last,
               :build, :create, :create!,
               :concat, :replace, :delete_all, :destroy_all, :delete, :destroy, :uniq,
               :sum, :count, :size, :length, :empty?,
               :any?, :many?, :include?,
               :to => :@association

      def initialize(association)
        @association = association
        Array.wrap(association.options[:extend]).each { |ext| proxy_extend(ext) }
      end

      alias_method :new, :build

      def proxy_association
        @association
      end

      def respond_to?(name, include_private = false)
        super ||
        (load_target && target.respond_to?(name, include_private)) ||
        proxy_association.klass.respond_to?(name, include_private)
      end

      def method_missing(method, *args, &block)
        match = DynamicFinderMatch.match(method)
        if match && match.instantiator?
          send(:find_or_instantiator_by_attributes, match, match.attribute_names, *args) do |r|
            proxy_association.send :set_owner_attributes, r
            proxy_association.send :add_to_target, r
            yield(r) if block_given?
          end
        end

        if target.respond_to?(method) || (!proxy_association.klass.respond_to?(method) && Class.respond_to?(method))
          if load_target
            if target.respond_to?(method)
              target.send(method, *args, &block)
            else
              begin
                super
              rescue NoMethodError => e
                raise e, e.message.sub(/ for #<.*$/, " via proxy for #{target}")
              end
            end
          end

        else
          scoped.readonly(nil).send(method, *args, &block)
        end
      end

      # Forwards <tt>===</tt> explicitly to the \target because the instance method
      # removal above doesn't catch it. Loads the \target if needed.
      def ===(other)
        other === load_target
      end

      def to_ary
        load_target.dup
      end
      alias_method :to_a, :to_ary

      def <<(*records)
        proxy_association.concat(records) && self
      end
      alias_method :push, :<<

      def clear
        delete_all
        self
      end

      def reload
        proxy_association.reload
        self
      end

      def proxy_owner
        ActiveSupport::Deprecation.warn(
          "Calling record.#{@association.reflection.name}.proxy_owner is deprecated. Please use " \
          "record.association(:#{@association.reflection.name}).owner instead. Or, from an " \
          "association extension you can access proxy_association.owner."
        )
        proxy_association.owner
      end

      def proxy_target
        ActiveSupport::Deprecation.warn(
          "Calling record.#{@association.reflection.name}.proxy_target is deprecated. Please use " \
          "record.association(:#{@association.reflection.name}).target instead. Or, from an " \
          "association extension you can access proxy_association.target."
        )
        proxy_association.target
      end

      def proxy_reflection
        ActiveSupport::Deprecation.warn(
          "Calling record.#{@association.reflection.name}.proxy_reflection is deprecated. Please use " \
          "record.association(:#{@association.reflection.name}).reflection instead. Or, from an " \
          "association extension you can access proxy_association.reflection."
        )
        proxy_association.reflection
      end
    end
  end
end
