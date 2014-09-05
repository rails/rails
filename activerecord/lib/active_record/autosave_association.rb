module ActiveRecord
  # = Active Record Autosave Association
  #
  # +AutosaveAssociation+ is a module that takes care of automatically saving
  # associated records when their parent is saved. In addition to saving, it
  # also destroys any associated records that were marked for destruction.
  # (See +mark_for_destruction+ and <tt>marked_for_destruction?</tt>).
  #
  # Saving of the parent, its associations, and the destruction of marked
  # associations, all happen inside a transaction. This should never leave the
  # database in an inconsistent state.
  #
  # If validations for any of the associations fail, their error messages will
  # be applied to the parent.
  #
  # Note that it also means that associations marked for destruction won't
  # be destroyed directly. They will however still be marked for destruction.
  #
  # Note that <tt>autosave: false</tt> is not same as not declaring <tt>:autosave</tt>.
  # When the <tt>:autosave</tt> option is not present then new association records are
  # saved but the updated association records are not saved.
  #
  # == Validation
  #
  # Children records are validated unless <tt>:validate</tt> is +false+.
  #
  # == Callbacks
  #
  # Association with autosave option defines several callbacks on your
  # model (before_save, after_create, after_update). Please note that
  # callbacks are executed in the order they were defined in
  # model. You should avoid modifying the association content, before
  # autosave callbacks are executed. Placing your callbacks after
  # associations is usually a good practice.
  #
  # === One-to-one Example
  #
  #   class Post < ActiveRecord::Base
  #     has_one :author, autosave: true
  #   end
  #
  # Saving changes to the parent and its associated model can now be performed
  # automatically _and_ atomically:
  #
  #   post = Post.find(1)
  #   post.title       # => "The current global position of migrating ducks"
  #   post.author.name # => "alloy"
  #
  #   post.title = "On the migration of ducks"
  #   post.author.name = "Eloy Duran"
  #
  #   post.save
  #   post.reload
  #   post.title       # => "On the migration of ducks"
  #   post.author.name # => "Eloy Duran"
  #
  # Destroying an associated model, as part of the parent's save action, is as
  # simple as marking it for destruction:
  #
  #   post.author.mark_for_destruction
  #   post.author.marked_for_destruction? # => true
  #
  # Note that the model is _not_ yet removed from the database:
  #
  #   id = post.author.id
  #   Author.find_by(id: id).nil? # => false
  #
  #   post.save
  #   post.reload.author # => nil
  #
  # Now it _is_ removed from the database:
  #
  #   Author.find_by(id: id).nil? # => true
  #
  # === One-to-many Example
  #
  # When <tt>:autosave</tt> is not declared new children are saved when their parent is saved:
  #
  #   class Post < ActiveRecord::Base
  #     has_many :comments # :autosave option is not declared
  #   end
  #
  #   post = Post.new(title: 'ruby rocks')
  #   post.comments.build(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.build(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.create(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  # When <tt>:autosave</tt> is true all children are saved, no matter whether they
  # are new records or not:
  #
  #   class Post < ActiveRecord::Base
  #     has_many :comments, autosave: true
  #   end
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.create(body: 'hello world')
  #   post.comments[0].body = 'hi everyone'
  #   post.comments.build(body: "good morning.")
  #   post.title += "!"
  #   post.save # => saves both post and comments.
  #
  # Destroying one of the associated models as part of the parent's save action
  # is as simple as marking it for destruction:
  #
  #   post.comments # => [#<Comment id: 1, ...>, #<Comment id: 2, ...]>
  #   post.comments[1].mark_for_destruction
  #   post.comments[1].marked_for_destruction? # => true
  #   post.comments.length # => 2
  #
  # Note that the model is _not_ yet removed from the database:
  #
  #   id = post.comments.last.id
  #   Comment.find_by(id: id).nil? # => false
  #
  #   post.save
  #   post.reload.comments.length # => 1
  #
  # Now it _is_ removed from the database:
  #
  #   Comment.find_by(id: id).nil? # => true

  module AutosaveAssociation
    extend ActiveSupport::Concern

    module AssociationBuilderExtension #:nodoc:
      def self.build(model, reflection)
        model.send(:add_autosave_association_callbacks, reflection)
      end

      def self.valid_options
        [ :autosave ]
      end
    end

    included do
      Associations::Builder::Association.extensions << AssociationBuilderExtension
    end

    module ClassMethods
      private

        def define_non_cyclic_method(name, &block)
          return if method_defined?(name)
          define_method(name) do |*args|
            result = true; @_already_called ||= {}
            # Loop prevention for validation of associations
            unless @_already_called[name]
              begin
                @_already_called[name]=true
                result = instance_eval(&block)
              ensure
                @_already_called[name]=false
              end
            end

            result
          end
        end

        # Adds validation and save callbacks for the association as specified by
        # the +reflection+.
        #
        # For performance reasons, we don't check whether to validate at runtime.
        # However the validation and callback methods are lazy and those methods
        # get created when they are invoked for the very first time. However,
        # this can change, for instance, when using nested attributes, which is
        # called _after_ the association has been defined. Since we don't want
        # the callbacks to get defined multiple times, there are guards that
        # check if the save or validation methods have already been defined
        # before actually defining them.
        def add_autosave_association_callbacks(reflection)
          save_method = :"autosave_associated_records_for_#{reflection.name}"
          validation_method = :"validate_associated_records_for_#{reflection.name}"
          collection = reflection.collection?

          if collection
            before_save :before_save_collection_association

            define_non_cyclic_method(save_method) { save_collection_association(reflection) }
            # Doesn't use after_save as that would save associations added in after_create/after_update twice
            after_create save_method
            after_update save_method
          elsif reflection.macro == :has_one
            define_method(save_method) { save_has_one_association(reflection) } unless method_defined?(save_method)
            # Configures two callbacks instead of a single after_save so that
            # the model may rely on their execution order relative to its
            # own callbacks.
            #
            # For example, given that after_creates run before after_saves, if
            # we configured instead an after_save there would be no way to fire
            # a custom after_create callback after the child association gets
            # created.
            after_create save_method
            after_update save_method
          else
            define_non_cyclic_method(save_method) { save_belongs_to_association(reflection) }
            before_save save_method
          end

          if reflection.validate? && !method_defined?(validation_method)
            method = (collection ? :validate_collection_association : :validate_single_association)
            define_non_cyclic_method(validation_method) { send(method, reflection) }
            validate validation_method
          end
        end
    end

    # Reloads the attributes of the object as usual and clears <tt>marked_for_destruction</tt> flag.
    def reload(options = nil)
      @marked_for_destruction = false
      @destroyed_by_association = nil
      super
    end

    # Marks this record to be destroyed as part of the parents save transaction.
    # This does _not_ actually destroy the record instantly, rather child record will be destroyed
    # when <tt>parent.save</tt> is called.
    #
    # Only useful if the <tt>:autosave</tt> option on the parent is enabled for this associated model.
    def mark_for_destruction
      @marked_for_destruction = true
    end

    # Returns whether or not this record will be destroyed as part of the parents save transaction.
    #
    # Only useful if the <tt>:autosave</tt> option on the parent is enabled for this associated model.
    def marked_for_destruction?
      @marked_for_destruction
    end

    # Records the association that is being destroyed and destroying this
    # record in the process.
    def destroyed_by_association=(reflection)
      @destroyed_by_association = reflection
    end

    # Returns the association for the parent being destroyed.
    #
    # Used to avoid updating the counter cache unnecessarily.
    def destroyed_by_association
      @destroyed_by_association
    end

    # Returns whether or not this record has been changed in any way (including whether
    # any of its nested autosave associations are likewise changed)
    def changed_for_autosave?
      new_record? || changed? || marked_for_destruction? || nested_records_changed_for_autosave?
    end

    private

      # Returns the record for an association collection that should be validated
      # or saved. If +autosave+ is +false+ only new records will be returned,
      # unless the parent is/was a new record itself.
      def associated_records_to_validate_or_save(association, new_record, autosave)
        if new_record
          association && association.target
        elsif autosave
          association.target.find_all { |record| record.changed_for_autosave? }
        else
          association.target.find_all { |record| record.new_record? }
        end
      end

      # go through nested autosave associations that are loaded in memory (without loading
      # any new ones), and return true if is changed for autosave
      def nested_records_changed_for_autosave?
        self.class._reflections.values.any? do |reflection|
          if reflection.options[:autosave]
            association = association_instance_get(reflection.name)
            association && Array.wrap(association.target).any? { |a| a.changed_for_autosave? }
          end
        end
      end

      # Validate the association if <tt>:validate</tt> or <tt>:autosave</tt> is
      # turned on for the association.
      def validate_single_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.reader
        association_valid?(reflection, record) if record
      end

      # Validate the associated records if <tt>:validate</tt> or
      # <tt>:autosave</tt> is turned on for the association specified by
      # +reflection+.
      def validate_collection_association(reflection)
        if association = association_instance_get(reflection.name)
          if records = associated_records_to_validate_or_save(association, new_record?, reflection.options[:autosave])
            records.each { |record| association_valid?(reflection, record) }
          end
        end
      end

      # Returns whether or not the association is valid and applies any errors to
      # the parent, <tt>self</tt>, if it wasn't. Skips any <tt>:autosave</tt>
      # enabled records if they're marked_for_destruction? or destroyed.
      def association_valid?(reflection, record)
        return true if record.destroyed? || record.marked_for_destruction?

        unless valid = record.valid?
          if reflection.options[:autosave]
            record.errors.each do |attribute, message|
              attribute = "#{reflection.name}.#{attribute}"
              errors[attribute] << message
              errors[attribute].uniq!
            end
          else
            errors.add(reflection.name)
          end
        end
        valid
      end

      # Is used as a before_save callback to check while saving a collection
      # association whether or not the parent was a new record before saving.
      def before_save_collection_association
        @new_record_before_save = new_record?
        true
      end

      # Saves any new associated records, or all loaded autosave associations if
      # <tt>:autosave</tt> is enabled on the association.
      #
      # In addition, it destroys all children that were marked for destruction
      # with mark_for_destruction.
      #
      # This all happens inside a transaction, _if_ the Transactions module is included into
      # ActiveRecord::Base after the AutosaveAssociation module, which it does by default.
      def save_collection_association(reflection)
        if association = association_instance_get(reflection.name)
          autosave = reflection.options[:autosave]

          if records = associated_records_to_validate_or_save(association, @new_record_before_save, autosave)
            if autosave
              records_to_destroy = records.select(&:marked_for_destruction?)
              records_to_destroy.each { |record| association.destroy(record) }
              records -= records_to_destroy
            end

            records.each do |record|
              next if record.destroyed?

              saved = true

              if autosave != false && (@new_record_before_save || record.new_record?)
                if autosave
                  saved = association.insert_record(record, false)
                else
                  association.insert_record(record) unless reflection.nested?
                end
              elsif autosave
                saved = record.save(:validate => false)
              end

              raise ActiveRecord::Rollback unless saved
            end
          end

          # reconstruct the scope now that we know the owner's id
          association.reset_scope if association.respond_to?(:reset_scope)
        end
      end

      # Saves the associated record if it's new or <tt>:autosave</tt> is enabled
      # on the association.
      #
      # In addition, it will destroy the association if it was marked for
      # destruction with mark_for_destruction.
      #
      # This all happens inside a transaction, _if_ the Transactions module is included into
      # ActiveRecord::Base after the AutosaveAssociation module, which it does by default.
      def save_has_one_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.load_target

        if record && !record.destroyed?
          autosave = reflection.options[:autosave]

          if autosave && record.marked_for_destruction?
            record.destroy
          elsif autosave != false
            key = reflection.options[:primary_key] ? send(reflection.options[:primary_key]) : id

            if (autosave && record.changed_for_autosave?) || new_record? || record_changed?(reflection, record, key)
              unless reflection.through_reflection
                record[reflection.foreign_key] = key
              end

              saved = record.save(:validate => !autosave)
              raise ActiveRecord::Rollback if !saved && autosave
              saved
            end
          end
        end
      end

      # If the record is new or it has changed, returns true.
      def record_changed?(reflection, record, key)
        record.new_record? || record[reflection.foreign_key] != key || record.attribute_changed?(reflection.foreign_key)
      end

      # Saves the associated record if it's new or <tt>:autosave</tt> is enabled.
      #
      # In addition, it will destroy the association if it was marked for destruction.
      def save_belongs_to_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.load_target
        if record && !record.destroyed?
          autosave = reflection.options[:autosave]

          if autosave && record.marked_for_destruction?
            self[reflection.foreign_key] = nil
            record.destroy
          elsif autosave != false
            saved = record.save(:validate => !autosave) if record.new_record? || (autosave && record.changed_for_autosave?)

            if association.updated?
              association_id = record.send(reflection.options[:primary_key] || :id)
              self[reflection.foreign_key] = association_id
              association.loaded!
            end

            saved if autosave
          end
        end
      end
  end
end
