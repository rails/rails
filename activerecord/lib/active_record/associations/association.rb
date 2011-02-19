require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module Associations
    # = Active Record Associations
    #
    # This is the root class of all associations ('+ Foo' signifies an included module Foo):
    #
    #   Association
    #     SingularAssociaton
    #       HasOneAssociation
    #         HasOneThroughAssociation + ThroughAssociation
    #       BelongsToAssociation
    #         BelongsToPolymorphicAssociation
    #     CollectionAssociation
    #       HasAndBelongsToManyAssociation
    #       HasManyAssociation
    #         HasManyThroughAssociation + ThroughAssociation
    class Association #:nodoc:
      attr_reader :owner, :target, :reflection

      delegate :options, :klass, :to => :reflection

      def initialize(owner, reflection)
        reflection.check_validity!

        @target = nil
        @owner, @reflection = owner, reflection
        @updated = false

        reset
        construct_scope
      end

      # Returns the name of the table of the related class:
      #
      #   post.comments.aliased_table_name # => "comments"
      #
      def aliased_table_name
        @reflection.klass.table_name
      end

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        @loaded = false
        IdentityMap.remove(@target) if IdentityMap.enabled? && @target
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
      def loaded!
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

      # Sets the target of this association to <tt>\target</tt>, and the \loaded flag to +true+.
      def target=(target)
        @target = target
        loaded!
      end

      def scoped
        target_scope.merge(@association_scope)
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
        scope = scope.apply_finder_options(@reflection.options.slice(:readonly, :include))
        scope = scope.where(interpolate(@reflection.options[:conditions]))
        if select = select_value
          scope = scope.select(select)
        end
        scope = scope.extending(*Array.wrap(@reflection.options[:extend]))
        scope.where(construct_owner_conditions)
      end

      def aliased_table
        target_klass.arel_table
      end

      # Set the inverse association, if possible
      def set_inverse_instance(record)
        if record && invertible_for?(record)
          inverse = record.association(inverse_reflection_for(record).name)
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
        if find_target?
          begin
            if IdentityMap.enabled? && association_class && association_class.respond_to?(:base_class)
              @target = IdentityMap.get(association_class, @owner[@reflection.foreign_key])
            end
          rescue NameError
            nil
          ensure
            @target ||= find_target
          end
        end
        loaded!
        target
      rescue ActiveRecord::RecordNotFound
        reset
      end

      private

        def find_target?
          !loaded? && (!@owner.new_record? || foreign_key_present?) && target_klass
        end

        def interpolate(sql, record = nil)
          if sql.respond_to?(:to_proc)
            @owner.send(:instance_exec, record, &sql)
          else
            sql
          end
        end

        def select_value
          @reflection.options[:select]
        end

        # Implemented by (some) subclasses
        def creation_attributes
          { }
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

        def association_class
          @reflection.klass
        end
    end
  end
end
