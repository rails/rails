module ActiveRecord
  module Associations
    # This is the root class of all association proxies:
    #
    #   AssociationProxy
    #     BelongsToAssociation
    #       HasOneAssociation
    #     BelongsToPolymorphicAssociation
    #     AssociationCollection
    #       HasAndBelongsToManyAssociation
    #       HasManyAssociation
    #         HasManyThroughAssociation
    #            HasOneThroughAssociation
    #
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
    #   blog = Blog.find(:first)
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
    # The <tt>@target</tt> object is not loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class AssociationProxy #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
      delegate :to_param, :to => :proxy_target
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_|^object_id$)/ }

      def initialize(owner, reflection)
        @owner, @reflection = owner, reflection
        Array(reflection.options[:extend]).each { |ext| proxy_extend(ext) }
        reset
      end

      def proxy_owner
        @owner
      end

      def proxy_reflection
        @reflection
      end

      def proxy_target
        @target
      end

      def respond_to?(*args)
        proxy_respond_to?(*args) || (load_target && @target.respond_to?(*args))
      end

      # Explicitly proxy === because the instance method removal above
      # doesn't catch it.
      def ===(other)
        load_target
        other === @target
      end

      def aliased_table_name
        @reflection.klass.table_name
      end

      def conditions
        @conditions ||= interpolate_sql(sanitize_sql(@reflection.options[:conditions])) if @reflection.options[:conditions]
      end
      alias :sql_conditions :conditions

      def reset
        @loaded = false
        @target = nil
      end

      def reload
        reset
        load_target
        self unless @target.nil?
      end

      def loaded?
        @loaded
      end

      def loaded
        @loaded = true
      end

      def target
        @target
      end

      def target=(target)
        @target = target
        loaded
      end

      def inspect
        load_target
        @target.inspect
      end

      protected
        def dependent?
          @reflection.options[:dependent]
        end

        def quoted_record_ids(records)
          records.map { |record| record.quoted_id }.join(',')
        end

        def interpolate_sql(sql, record = nil)
          @owner.send(:interpolate_sql, sql, record)
        end

        def sanitize_sql(sql)
          @reflection.klass.send(:sanitize_sql, sql)
        end

        def set_belongs_to_association_for(record)
          if @reflection.options[:as]
            record["#{@reflection.options[:as]}_id"]   = @owner.id unless @owner.new_record?
            record["#{@reflection.options[:as]}_type"] = @owner.class.base_class.name.to_s
          else
            record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
          end
        end

        def merge_options_from_reflection!(options)
          options.reverse_merge!(
            :group   => @reflection.options[:group],
            :limit   => @reflection.options[:limit],
            :offset  => @reflection.options[:offset],
            :joins   => @reflection.options[:joins],
            :include => @reflection.options[:include],
            :select  => @reflection.options[:select],
            :readonly  => @reflection.options[:readonly]
          )
        end

        def with_scope(*args, &block)
          @reflection.klass.send :with_scope, *args, &block
        end

      private
        def method_missing(method, *args)
          if load_target
            if block_given?
              @target.send(method, *args)  { |*block_args| yield(*block_args) }
            else
              @target.send(method, *args)
            end
          end
        end

        # Loads the target if needed and returns it.
        #
        # This method is abstract in the sense that it relies on +find_target+,
        # which is expected to be provided by descendants.
        #
        # If the target is already loaded it is just returned. Thus, you can call
        # +load_target+ unconditionally to get the target.
        #
        # ActiveRecord::RecordNotFound is rescued within the method, and it is
        # not reraised. The proxy is reset and +nil+ is the return value.
        def load_target
          return nil unless defined?(@loaded)

          if !loaded? and (!@owner.new_record? || foreign_key_present)
            @target = find_target
          end

          @loaded = true
          @target
        rescue ActiveRecord::RecordNotFound
          reset
        end

        # Can be overwritten by associations that might have the foreign key available for an association without
        # having the object itself (and still being a new record). Currently, only belongs_to presents this scenario.
        def foreign_key_present
          false
        end

        def raise_on_type_mismatch(record)
          unless record.is_a?(@reflection.klass)
            message = "#{@reflection.class_name}(##{@reflection.klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"
            raise ActiveRecord::AssociationTypeMismatch, message
          end
        end

        # Array#flatten has problems with recursive arrays. Going one level deeper solves the majority of the problems.
        def flatten_deeper(array)
          array.collect { |element| element.respond_to?(:flatten) ? element.flatten : element }.flatten
        end
    end
  end
end
