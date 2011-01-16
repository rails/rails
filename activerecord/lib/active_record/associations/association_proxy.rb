require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module Associations
    # = Active Record Associations
    #
    # This is the root class of all association proxies ('+ Foo' signifies an included module Foo):
    #
    #   AssociationProxy
    #     SingularAssociaton
    #       HasOneAssociation
    #         HasOneThroughAssociation + ThroughAssociation
    #       BelongsToAssociation
    #         BelongsToPolymorphicAssociation
    #     AssociationCollection
    #       HasAndBelongsToManyAssociation
    #       HasManyAssociation
    #         HasManyThroughAssociation + ThroughAssociation
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
    # The <tt>@target</tt> object is not \loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class AssociationProxy #:nodoc:
      alias_method :proxy_extend, :extend

      instance_methods.each { |m| undef_method m unless m.to_s =~ /^(?:nil\?|send|object_id|to_a)$|^__|^respond_to|proxy_/ }

      def initialize(owner, reflection)
        @owner, @reflection = owner, reflection
        @updated = false
        reflection.check_validity!
        Array.wrap(reflection.options[:extend]).each { |ext| proxy_extend(ext) }
        reset
        construct_scope
      end

      def to_param
        proxy_target.to_param
      end

      # Returns the owner of the proxy.
      def proxy_owner
        @owner
      end

      # Returns the reflection object that represents the association handled
      # by the proxy.
      def proxy_reflection
        @reflection
      end

      # Does the proxy or its \target respond to +symbol+?
      def respond_to?(*args)
        super || (load_target && @target.respond_to?(*args))
      end

      # Forwards <tt>===</tt> explicitly to the \target because the instance method
      # removal above doesn't catch it. Loads the \target if needed.
      def ===(other)
        other === load_target
      end

      # Returns the name of the table of the related class:
      #
      #   post.comments.aliased_table_name # => "comments"
      #
      def aliased_table_name
        @reflection.klass.table_name
      end

      # Returns the SQL string that corresponds to the <tt>:conditions</tt>
      # option of the macro, if given, or +nil+ otherwise.
      def conditions
        @conditions ||= interpolate_sql(@reflection.sanitized_conditions) if @reflection.sanitized_conditions
      end
      alias :sql_conditions :conditions

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        @loaded = false
        @target = nil
      end

      # Reloads the \target and returns +self+ on success.
      def reload
        reset
        construct_scope
        load_target
        self unless @target.nil?
      end

      # Has the \target been already \loaded?
      def loaded?
        @loaded
      end

      # Asserts the \target has been loaded setting the \loaded flag to +true+.
      def loaded
        @loaded      = true
        @stale_state = stale_state
      end

      # The target is stale if the target no longer points to the record(s) that the
      # relevant foreign_key(s) refers to. If stale, the association accessor method
      # on the owner will reload the target. It's up to subclasses to implement the
      # state_state method if relevant.
      #
      # Note that if the target has not been loaded, it is not considered stale.
      def stale_target?
        loaded? && @stale_state != stale_state
      end

      # Returns the target of this proxy, same as +proxy_target+.
      attr_reader :target

      # Returns the \target of the proxy, same as +target+.
      alias :proxy_target :target

      # Sets the target of this proxy to <tt>\target</tt>, and the \loaded flag to +true+.
      def target=(target)
        @target = target
        loaded
      end

      # Forwards the call to the target. Loads the \target if needed.
      def inspect
        load_target.inspect
      end

      def send(method, *args)
        return super if respond_to?(method)
        load_target.send(method, *args)
      end

      def scoped
        target_scope & @association_scope
      end

      protected
        def interpolate_sql(sql, record = nil)
          @owner.send(:interpolate_sql, sql, record)
        end

        # Forwards the call to the reflection class.
        def sanitize_sql(sql, table_name = @reflection.klass.table_name)
          @reflection.klass.send(:sanitize_sql, sql, table_name)
        end

        # Construct the scope for this association.
        #
        # Note that the association_scope is merged into the targed_scope only when the
        # scoped method is called. This is because at that point the call may be surrounded
        # by scope.scoping { ... } or with_scope { ... } etc, which affects the scope which
        # actually gets built.
        def construct_scope
          @association_scope = association_scope if target_klass
        end

        def association_scope
          scope = target_klass.unscoped
          scope = scope.create_with(creation_attributes)
          scope = scope.apply_finder_options(@reflection.options.slice(:conditions, :readonly, :include))
          scope = scope.select(select_value) if select_value = self.select_value
          scope.where(construct_owner_conditions)
        end

        def select_value
          @reflection.options[:select]
        end

        # Implemented by (some) subclasses
        def creation_attributes
          { }
        end

        def aliased_table
          target_klass.arel_table
        end

        # Set the inverse association, if possible
        def set_inverse_instance(record)
          if record && invertible_for?(record)
            inverse = record.send(:association_proxy, inverse_reflection_for(record).name)
            inverse.target = @owner
          end
        end

        # This class of the target. belongs_to polymorphic overrides this to look at the
        # polymorphic_type field on the owner.
        def target_klass
          @reflection.klass
        end

        # Can be overridden (i.e. in ThroughAssociation) to merge in other scopes (i.e. the
        # through association's scope)
        def target_scope
          target_klass.scoped
        end

        # Returns a hash linking the owner to the association represented by the reflection
        def construct_owner_attributes(reflection = @reflection)
          attributes = {}
          if reflection.macro == :belongs_to
            attributes[reflection.association_primary_key] = @owner[reflection.foreign_key]
          else
            attributes[reflection.foreign_key] = @owner[reflection.active_record_primary_key]

            if reflection.options[:as]
              attributes["#{reflection.options[:as]}_type"] = @owner.class.base_class.name
            end
          end
          attributes
        end

        # Builds an array of arel nodes from the owner attributes hash
        def construct_owner_conditions(table = aliased_table, reflection = @reflection)
          conditions = construct_owner_attributes(reflection).map do |attr, value|
            table[attr].eq(value)
          end
          table.create_and(conditions)
        end

        # Sets the owner attributes on the given record
        def set_owner_attributes(record)
          if @owner.persisted?
            construct_owner_attributes.each { |key, value| record[key] = value }
          end
        end

        # Loads the \target if needed and returns it.
        #
        # This method is abstract in the sense that it relies on +find_target+,
        # which is expected to be provided by descendants.
        #
        # If the \target is already \loaded it is just returned. Thus, you can call
        # +load_target+ unconditionally to get the \target.
        #
        # ActiveRecord::RecordNotFound is rescued within the method, and it is
        # not reraised. The proxy is \reset and +nil+ is the return value.
        def load_target
          if !loaded? && (!@owner.new_record? || foreign_key_present?) && target_klass
            @target = find_target
          end

          loaded
          @target
        rescue ActiveRecord::RecordNotFound
          reset
        end

      private

        # Forwards any missing method call to the \target.
        def method_missing(method, *args, &block)
          if load_target
            return super unless @target.respond_to?(method)
            @target.send(method, *args, &block)
          end
        rescue NoMethodError => e
          raise e, e.message.sub(/ for #<.*$/, " via proxy for #{@target}")
        end

        # Should be true if there is a foreign key present on the @owner which
        # references the target. This is used to determine whether we can load
        # the target if the @owner is currently a new record (and therefore
        # without a key).
        #
        # Currently implemented by belongs_to (vanilla and polymorphic) and
        # has_one/has_many :through associations which go through a belongs_to
        def foreign_key_present?
          false
        end

        # Raises ActiveRecord::AssociationTypeMismatch unless +record+ is of
        # the kind of the class of the associated objects. Meant to be used as
        # a sanity check when you are about to assign an associated record.
        def raise_on_type_mismatch(record)
          unless record.is_a?(@reflection.klass) || record.is_a?(@reflection.class_name.constantize)
            message = "#{@reflection.class_name}(##{@reflection.klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"
            raise ActiveRecord::AssociationTypeMismatch, message
          end
        end

        # Can be redefined by subclasses, notably polymorphic belongs_to
        # The record parameter is necessary to support polymorphic inverses as we must check for
        # the association in the specific class of the record.
        def inverse_reflection_for(record)
          @reflection.inverse_of
        end

        # Is this association invertible? Can be redefined by subclasses.
        def invertible_for?(record)
          inverse_reflection_for(record)
        end

        # This should be implemented to return the values of the relevant key(s) on the owner,
        # so that when state_state is different from the value stored on the last find_target,
        # the target is stale.
        #
        # This is only relevant to certain associations, which is why it returns nil by default.
        def stale_state
        end
    end
  end
end
