module ActiveRecord
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
  #   post.errors # => #<ActiveRecord::Errors:0x174498c @errors={"author_name"=>["can't be blank"]}, @base=#<Post ...>>
  #
  # No validations will be performed on the associated models when validations
  # are skipped for the parent:
  #
  #   post = Post.find(1)
  #   post.author.name = ''
  #   post.save(false) # => true
  module AutosaveAssociation
    ASSOCIATION_TYPES = %w{ has_one belongs_to has_many has_and_belongs_to_many }

    def self.included(base)
      base.class_eval do
        base.extend(ClassMethods)
        alias_method_chain :reload, :autosave_associations

        ASSOCIATION_TYPES.each do |type|
          base.send("valid_keys_for_#{type}_association") << :autosave
        end
      end
    end

    module ClassMethods
      private

      # def belongs_to(name, options = {})
      #   super
      #   add_autosave_association_callbacks(reflect_on_association(name))
      # end
      ASSOCIATION_TYPES.each do |type|
        module_eval %{
          def #{type}(name, options = {})
            super
            add_autosave_association_callbacks(reflect_on_association(name))
          end
        }
      end

      # Adds a validate and save callback for the association as specified by
      # the +reflection+.
      def add_autosave_association_callbacks(reflection)
        save_method = "autosave_associated_records_for_#{reflection.name}"
        validation_method = "validate_associated_records_for_#{reflection.name}"
        validate validation_method

        case reflection.macro
        when :has_many, :has_and_belongs_to_many
          before_save :before_save_collection_association

          define_method(save_method) { save_collection_association(reflection) }
          # Doesn't use after_save as that would save associations added in after_create/after_update twice
          after_create save_method
          after_update save_method

          define_method(validation_method) { validate_collection_association(reflection) }
        else
          case reflection.macro
          when :has_one
            define_method(save_method) { save_has_one_association(reflection) }
            after_save save_method
          when :belongs_to
            define_method(save_method) { save_belongs_to_association(reflection) }
            before_save save_method
          end
          define_method(validation_method) { validate_single_association(reflection) }
        end
      end
    end

    # Reloads the attributes of the object as usual and removes a mark for destruction.
    def reload_with_autosave_associations(options = nil)
      @marked_for_destruction = false
      reload_without_autosave_associations(options)
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

    private

    # Returns the record for an association collection that should be validated
    # or saved. If +autosave+ is +false+ only new records will be returned,
    # unless the parent is/was a new record itself.
    def associated_records_to_validate_or_save(association, new_record, autosave)
      if new_record
        association
      elsif association.loaded?
        autosave ? association : association.select { |record| record.new_record? }
      else
        autosave ? association.target : association.target.select { |record| record.new_record? }
      end
    end

    # Validate the association if <tt>:validate</tt> or <tt>:autosave</tt> is
    # turned on for the association specified by +reflection+.
    def validate_single_association(reflection)
      if reflection.options[:validate] == true || reflection.options[:autosave] == true
        if (association = association_instance_get(reflection.name)) && !association.target.nil?
          association_valid?(reflection, association)
        end
      end
    end

    # Validate the associated records if <tt>:validate</tt> or
    # <tt>:autosave</tt> is turned on for the association specified by
    # +reflection+.
    def validate_collection_association(reflection)
      if reflection.options[:validate] != false && association = association_instance_get(reflection.name)
        if records = associated_records_to_validate_or_save(association, new_record?, reflection.options[:autosave])
          records.each { |record| association_valid?(reflection, record) }
        end
      end
    end

    # Returns whether or not the association is valid and applies any errors to
    # the parent, <tt>self</tt>, if it wasn't. Skips any <tt>:autosave</tt>
    # enabled records if they're marked_for_destruction?.
    def association_valid?(reflection, association)
      unless valid = association.valid?
        if reflection.options[:autosave]
          unless association.marked_for_destruction?
            association.errors.each do |attribute, message|
              attribute = "#{reflection.name}_#{attribute}"
              errors.add(attribute, message) unless errors.on(attribute)
            end
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
            if autosave && record.marked_for_destruction?
              association.destroy(record)
            elsif @new_record_before_save || record.new_record?
              if autosave
                association.send(:insert_record, record, false, false)
              else
                association.send(:insert_record, record)
              end
            elsif autosave
              record.save(false)
            end
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
      if (association = association_instance_get(reflection.name)) && !association.target.nil?
        autosave = reflection.options[:autosave]

        if autosave && association.marked_for_destruction?
          association.destroy
        elsif new_record? || association.new_record? || association[reflection.primary_key_name] != id || autosave
          association[reflection.primary_key_name] = id
          association.save(!autosave)
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
      if association = association_instance_get(reflection.name)
        autosave = reflection.options[:autosave]

        if autosave && association.marked_for_destruction?
          association.destroy
        else
          association.save(!autosave) if association.new_record? || autosave

          if association.updated?
            self[reflection.primary_key_name] = association.id
            # TODO: Removing this code doesn't seem to matter…
            if reflection.options[:polymorphic]
              self[reflection.options[:foreign_type]] = association.class.base_class.name.to_s
            end
          end
        end
      end
    end
  end
end