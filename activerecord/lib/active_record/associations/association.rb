# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Associations
    #
    # This is the root class of all associations ('+ Foo' signifies an included module Foo):
    #
    #   Association
    #     SingularAssociation
    #       HasOneAssociation + ForeignAssociation
    #         HasOneThroughAssociation + ThroughAssociation
    #       BelongsToAssociation
    #         BelongsToPolymorphicAssociation
    #     CollectionAssociation
    #       HasManyAssociation + ForeignAssociation
    #         HasManyThroughAssociation + ThroughAssociation
    #
    # Associations in Active Record are middlemen between the object that
    # holds the association, known as the <tt>owner</tt>, and the associated
    # result set, known as the <tt>target</tt>. Association metadata is available in
    # <tt>reflection</tt>, which is an instance of <tt>ActiveRecord::Reflection::AssociationReflection</tt>.
    #
    # For example, given
    #
    #   class Blog < ActiveRecord::Base
    #     has_many :posts
    #   end
    #
    #   blog = Blog.first
    #
    # The association of <tt>blog.posts</tt> has the object +blog+ as its
    # <tt>owner</tt>, the collection of its posts as <tt>target</tt>, and
    # the <tt>reflection</tt> object represents a <tt>:has_many</tt> macro.
    class Association #:nodoc:
      attr_reader :owner, :target, :reflection

      delegate :options, to: :reflection

      def initialize(owner, reflection)
        reflection.check_validity!

        @owner, @reflection = owner, reflection

        reset
        reset_scope
      end

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        @loaded = false
        @target = nil
        @stale_state = nil
        @inversed = false
      end

      def reset_negative_cache # :nodoc:
        reset if loaded? && target.nil?
      end

      # Reloads the \target and returns +self+ on success.
      # The QueryCache is cleared if +force+ is true.
      def reload(force = false)
        klass.connection.clear_query_cache if force && klass
        reset
        reset_scope
        load_target
        self unless target.nil?
      end

      # Has the \target been already \loaded?
      def loaded?
        @loaded
      end

      # Asserts the \target has been loaded setting the \loaded flag to +true+.
      def loaded!
        @loaded = true
        @stale_state = stale_state
        @inversed = false
      end

      # The target is stale if the target no longer points to the record(s) that the
      # relevant foreign_key(s) refers to. If stale, the association accessor method
      # on the owner will reload the target. It's up to subclasses to implement the
      # stale_state method if relevant.
      #
      # Note that if the target has not been loaded, it is not considered stale.
      def stale_target?
        !@inversed && loaded? && @stale_state != stale_state
      end

      # Sets the target of this association to <tt>\target</tt>, and the \loaded flag to +true+.
      def target=(target)
        @target = target
        loaded!
      end

      def scope
        if (scope = klass.current_scope) && scope.try(:proxy_association) == self
          scope.spawn
        elsif scope = klass.global_current_scope
          target_scope.merge!(association_scope).merge!(scope)
        else
          target_scope.merge!(association_scope)
        end
      end

      def reset_scope
        @association_scope = nil
      end

      # Set the inverse association, if possible
      def set_inverse_instance(record)
        if inverse = inverse_association_for(record)
          inverse.inversed_from(owner)
        end
        record
      end

      def set_inverse_instance_from_queries(record)
        if inverse = inverse_association_for(record)
          inverse.inversed_from_queries(owner)
        end
        record
      end

      # Remove the inverse association, if possible
      def remove_inverse_instance(record)
        if inverse = inverse_association_for(record)
          inverse.inversed_from(nil)
        end
      end

      def inversed_from(record)
        self.target = record
        @inversed = !!record
      end

      def inversed_from_queries(record)
        if inversable?(record)
          self.target = record
          @inversed = true
        else
          @inversed = false
        end
      end

      # Returns the class of the target. belongs_to polymorphic overrides this to look at the
      # polymorphic_type field on the owner.
      def klass
        reflection.klass
      end

      def extensions
        extensions = klass.default_extensions | reflection.extensions

        if reflection.scope
          extensions |= reflection.scope_for(klass.unscoped, owner).extensions
        end

        extensions
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
        @target = find_target if (@stale_state && stale_target?) || find_target?

        loaded! unless loaded?
        target
      rescue ActiveRecord::RecordNotFound
        reset
      end

      # We can't dump @reflection and @through_reflection since it contains the scope proc
      def marshal_dump
        ivars = (instance_variables - [:@reflection, :@through_reflection]).map { |name| [name, instance_variable_get(name)] }
        [@reflection.name, ivars]
      end

      def marshal_load(data)
        reflection_name, ivars = data
        ivars.each { |name, val| instance_variable_set(name, val) }
        @reflection = @owner.class._reflect_on_association(reflection_name)
      end

      def initialize_attributes(record, except_from_scope_attributes = nil) #:nodoc:
        except_from_scope_attributes ||= {}
        skip_assign = [reflection.foreign_key, reflection.type].compact
        assigned_keys = record.changed_attribute_names_to_save
        assigned_keys += except_from_scope_attributes.keys.map(&:to_s)
        attributes = scope_for_create.except!(*(assigned_keys - skip_assign))
        record.send(:_assign_attributes, attributes) if attributes.any?
        set_inverse_instance(record)
      end

      def create(attributes = nil, &block)
        _create_record(attributes, &block)
      end

      def create!(attributes = nil, &block)
        _create_record(attributes, true, &block)
      end

      def check_strict_loading_violation!
        if (owner.strict_loading? || reflection.strict_loading?) && owner.validation_context.nil?
          Base.strict_loading_violation!(owner: owner.class, reflection: reflection)
        end
      end

      private
        def find_target
          check_strict_loading_violation!

          scope = self.scope
          return scope.to_a if skip_statement_cache?(scope)

          sc = reflection.association_scope_cache(klass, owner) do |params|
            as = AssociationScope.create { params.bind }
            target_scope.merge!(as.scope(self))
          end

          binds = AssociationScope.get_bind_values(owner, reflection.chain)
          sc.execute(binds, klass.connection) { |record| set_inverse_instance(record) }
        end

        # The scope for this association.
        #
        # Note that the association_scope is merged into the target_scope only when the
        # scope method is called. This is because at that point the call may be surrounded
        # by scope.scoping { ... } or unscoped { ... } etc, which affects the scope which
        # actually gets built.
        def association_scope
          if klass
            @association_scope ||= AssociationScope.scope(self)
          end
        end

        # Can be overridden (i.e. in ThroughAssociation) to merge in other scopes (i.e. the
        # through association's scope)
        def target_scope
          AssociationRelation.create(klass, self).merge!(klass.scope_for_association)
        end

        def scope_for_create
          scope.scope_for_create
        end

        def find_target?
          !loaded? && (!owner.new_record? || foreign_key_present?) && klass
        end

        # Returns true if there is a foreign key present on the owner which
        # references the target. This is used to determine whether we can load
        # the target if the owner is currently a new record (and therefore
        # without a key). If the owner is a new record then foreign_key must
        # be present in order to load target.
        #
        # Currently implemented by belongs_to (vanilla and polymorphic) and
        # has_one/has_many :through associations which go through a belongs_to.
        def foreign_key_present?
          false
        end

        # Raises ActiveRecord::AssociationTypeMismatch unless +record+ is of
        # the kind of the class of the associated objects. Meant to be used as
        # a sanity check when you are about to assign an associated record.
        def raise_on_type_mismatch!(record)
          unless record.is_a?(reflection.klass)
            fresh_class = reflection.class_name.safe_constantize
            unless fresh_class && record.is_a?(fresh_class)
              message = "#{reflection.class_name}(##{reflection.klass.object_id}) expected, "\
                "got #{record.inspect} which is an instance of #{record.class}(##{record.class.object_id})"
              raise ActiveRecord::AssociationTypeMismatch, message
            end
          end
        end

        def inverse_association_for(record)
          if invertible_for?(record)
            record.association(inverse_reflection_for(record).name)
          end
        end

        # Can be redefined by subclasses, notably polymorphic belongs_to
        # The record parameter is necessary to support polymorphic inverses as we must check for
        # the association in the specific class of the record.
        def inverse_reflection_for(record)
          reflection.inverse_of
        end

        # Returns true if inverse association on the given record needs to be set.
        # This method is redefined by subclasses.
        def invertible_for?(record)
          foreign_key_for?(record) && inverse_reflection_for(record)
        end

        # Returns true if record contains the foreign_key
        def foreign_key_for?(record)
          record._has_attribute?(reflection.foreign_key)
        end

        # This should be implemented to return the values of the relevant key(s) on the owner,
        # so that when stale_state is different from the value stored on the last find_target,
        # the target is stale.
        #
        # This is only relevant to certain associations, which is why it returns +nil+ by default.
        def stale_state
        end

        def build_record(attributes)
          reflection.build_association(attributes) do |record|
            initialize_attributes(record, attributes)
            yield(record) if block_given?
          end
        end

        # Returns true if statement cache should be skipped on the association reader.
        def skip_statement_cache?(scope)
          reflection.has_scope? ||
            scope.eager_loading? ||
            klass.scope_attributes? ||
            reflection.source_reflection.active_record.default_scopes.any?
        end

        def enqueue_destroy_association(options)
          job_class = owner.class.destroy_association_async_job

          if job_class
            owner._after_commit_jobs.push([job_class, options])
          end
        end

        def inversable?(record)
          record &&
            ((!record.persisted? || !owner.persisted?) || matches_foreign_key?(record))
        end

        def matches_foreign_key?(record)
          if foreign_key_for?(record)
            record.read_attribute(reflection.foreign_key) == owner.id ||
              (foreign_key_for?(owner) && owner.read_attribute(reflection.foreign_key) == record.id)
          else
            owner.read_attribute(reflection.foreign_key) == record.id
          end
        end
    end
  end
end
