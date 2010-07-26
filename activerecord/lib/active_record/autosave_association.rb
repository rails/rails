require 'active_support/core_ext/array/wrap'

module ActiveRecord
  # = Active Record Autosave Association
  # 
  # AutosaveAssociation is a module that takes care of automatically saving
  # your associations when the parent is saved. In addition to saving, it
  # also destroys any associations that were marked for destruction.
  # (See mark_for_destruction and marked_for_destruction?)
  #
  # Saving of the parent, its associations, and the destruction of marked
  # associations, all happen inside 1 transaction. This should never leave the
  # database in an inconsistent state after, for instance, mass assigning
  # attributes and saving them.
  #
  # If validations for any of the associations fail, their error messages will
  # be applied to the parent.
  #
  # Note that it also means that associations marked for destruction won't
  # be destroyed directly. They will however still be marked for destruction.
  #
  # === One-to-one Example
  #
  # Consider a Post model with one Author:
  #
  #   class Post
  #     has_one :author, :autosave => true
  #   end
  #
  # Saving changes to the parent and its associated model can now be performed
  # automatically _and_ atomically:
  #
  #   post = Post.find(1)
  #   post.title # => "The current global position of migrating ducks"
  #   post.author.name # => "alloy"
  #
  #   post.title = "On the migration of ducks"
  #   post.author.name = "Eloy Duran"
  #
  #   post.save
  #   post.reload
  #   post.title # => "On the migration of ducks"
  #   post.author.name # => "Eloy Duran"
  #
  # Destroying an associated model, as part of the parent's save action, is as
  # simple as marking it for destruction:
  #
  #   post.author.mark_for_destruction
  #   post.author.marked_for_destruction? # => true
  #
  # Note that the model is _not_ yet removed from the database:
  #   id = post.author.id
  #   Author.find_by_id(id).nil? # => false
  #
  #   post.save
  #   post.reload.author # => nil
  #
  # Now it _is_ removed from the database:
  #   Author.find_by_id(id).nil? # => true
  #
  # === One-to-many Example
  #
  # Consider a Post model with many Comments:
  #
  #   class Post
  #     has_many :comments, :autosave => true
  #   end
  #
  # Saving changes to the parent and its associated model can now be performed
  # automatically _and_ atomically:
  #
  #   post = Post.find(1)
  #   post.title # => "The current global position of migrating ducks"
  #   post.comments.first.body # => "Wow, awesome info thanks!"
  #   post.comments.last.body # => "Actually, your article should be named differently."
  #
  #   post.title = "On the migration of ducks"
  #   post.comments.last.body = "Actually, your article should be named differently. [UPDATED]: You are right, thanks."
  #
  #   post.save
  #   post.reload
  #   post.title # => "On the migration of ducks"
  #   post.comments.last.body # => "Actually, your article should be named differently. [UPDATED]: You are right, thanks."
  #
  # Destroying one of the associated models members, as part of the parent's
  # save action, is as simple as marking it for destruction:
  #
  #   post.comments.last.mark_for_destruction
  #   post.comments.last.marked_for_destruction? # => true
  #   post.comments.length # => 2
  #
  # Note that the model is _not_ yet removed from the database:
  #   id = post.comments.last.id
  #   Comment.find_by_id(id).nil? # => false
  #
  #   post.save
  #   post.reload.comments.length # => 1
  #
  # Now it _is_ removed from the database:
  #   Comment.find_by_id(id).nil? # => true
  #
  # === Validation
  #
  # Validation is performed on the parent as usual, but also on all autosave
  # enabled associations. If any of the associations fail validation, its
  # error messages will be applied on the parents errors object and validation
  # of the parent will fail.
  #
  # Consider a Post model with Author which validates the presence of its name
  # attribute:
  #
  #   class Post
  #     has_one :author, :autosave => true
  #   end
  #
  #   class Author
  #     validates_presence_of :name
  #   end
  #
  #   post = Post.find(1)
  #   post.author.name = ''
  #   post.save # => false
  #   post.errors # => #<ActiveRecord::Errors:0x174498c @errors={"author.name"=>["can't be blank"]}, @base=#<Post ...>>
  #
  # No validations will be performed on the associated models when validations
  # are skipped for the parent:
  #
  #   post = Post.find(1)
  #   post.author.name = ''
  #   post.save(:validate => false) # => true
  module AutosaveAssociation
    extend ActiveSupport::Concern

    ASSOCIATION_TYPES = %w{ has_one belongs_to has_many has_and_belongs_to_many }

    included do
      ASSOCIATION_TYPES.each do |type|
        send("valid_keys_for_#{type}_association") << :autosave
      end
    end

    module ClassMethods
      private

      # def belongs_to(name, options = {})
      #   super
      #   add_autosave_association_callbacks(reflect_on_association(name))
      # end
      ASSOCIATION_TYPES.each do |type|
        module_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{type}(name, options = {})
            super
            add_autosave_association_callbacks(reflect_on_association(name))
          end
        CODE
      end

      # Adds a validate and save callback for the association as specified by
      # the +reflection+.
      #
      # For performance reasons, we don't check whether to validate at runtime,
      # but instead only define the method and callback when needed. However,
      # this can change, for instance, when using nested attributes, which is
      # called _after_ the association has been defined. Since we don't want
      # the callbacks to get defined multiple times, there are guards that
      # check if the save or validation methods have already been defined
      # before actually defining them.
      def add_autosave_association_callbacks(reflection)
        save_method = :"autosave_associated_records_for_#{reflection.name}"
        validation_method = :"validate_associated_records_for_#{reflection.name}"
        collection = reflection.collection?

        unless method_defined?(save_method)
          if collection
            before_save :before_save_collection_association

            define_method(save_method) { save_collection_association(reflection) }
            # Doesn't use after_save as that would save associations added in after_create/after_update twice
            after_create save_method
            after_update save_method
          else
            if reflection.macro == :has_one
              define_method(save_method) { save_has_one_association(reflection) }
              after_save save_method
            else
              define_method(save_method) { save_belongs_to_association(reflection) }
              before_save save_method
            end
          end
        end

        if reflection.validate? && !method_defined?(validation_method)
          method = (collection ? :validate_collection_association : :validate_single_association)
          define_method(validation_method) { send(method, reflection) }
          validate validation_method
        end
      end
    end

    # Reloads the attributes of the object as usual and removes a mark for destruction.
    def reload(options = nil)
      @marked_for_destruction = false
      super
    end

    # Marks this record to be destroyed as part of the parents save transaction.
    # This does _not_ actually destroy the record yet, rather it will be destroyed when <tt>parent.save</tt> is called.
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
        association
      elsif autosave
        association.target.find_all { |record| record.changed_for_autosave? }
      else
        association.target.find_all { |record| record.new_record? }
      end
    end

    # go through nested autosave associations that are loaded in memory (without loading
    # any new ones), and return true if is changed for autosave
    def nested_records_changed_for_autosave?
      self.class.reflect_on_all_autosave_associations.any? do |reflection|
        association = association_instance_get(reflection.name)
        association && Array.wrap(association.target).any?(&:changed_for_autosave?)
      end
    end
    
    # Validate the association if <tt>:validate</tt> or <tt>:autosave</tt> is
    # turned on for the association specified by +reflection+.
    def validate_single_association(reflection)
      if (association = association_instance_get(reflection.name)) && !association.target.nil?
        association_valid?(reflection, association)
      end
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
    def association_valid?(reflection, association)
      return true if association.destroyed? || association.marked_for_destruction?

      unless valid = association.valid?
        if reflection.options[:autosave]
          association.errors.each do |attribute, message|
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
          records.each do |record|
            next if record.destroyed?

            if autosave && record.marked_for_destruction?
              association.destroy(record)
            elsif autosave != false && (@new_record_before_save || record.new_record?)
              if autosave
                saved = association.send(:insert_record, record, false, false)
              else
                association.send(:insert_record, record)
              end
            elsif autosave
              saved = record.save(:validate => false)
            end

            raise ActiveRecord::Rollback if saved == false
          end
        end

        # reconstruct the SQL queries now that we know the owner's id
        association.send(:construct_sql) if association.respond_to?(:construct_sql)
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
      if (association = association_instance_get(reflection.name)) && !association.target.nil? && !association.destroyed?
        autosave = reflection.options[:autosave]

        if autosave && association.marked_for_destruction?
          association.destroy
        else
          key = reflection.options[:primary_key] ? send(reflection.options[:primary_key]) : id
          if autosave != false && (new_record? || association.new_record? || association[reflection.primary_key_name] != key || autosave)
            association[reflection.primary_key_name] = key
            saved = association.save(:validate => !autosave)
            raise ActiveRecord::Rollback if !saved && autosave
            saved
          end
        end
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
    def save_belongs_to_association(reflection)
      if (association = association_instance_get(reflection.name)) && !association.destroyed?
        autosave = reflection.options[:autosave]

        if autosave && association.marked_for_destruction?
          association.destroy
        elsif autosave != false
          saved = association.save(:validate => !autosave) if association.new_record? || autosave

          if association.updated?
            association_id = association.send(reflection.options[:primary_key] || :id)
            self[reflection.primary_key_name] = association_id
          end

          saved if autosave
        end
      end
    end
  end
end