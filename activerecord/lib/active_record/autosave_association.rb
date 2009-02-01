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
    def self.included(base)
      base.class_eval do
        alias_method_chain :reload, :autosave_associations
        alias_method_chain :save,   :autosave_associations
        alias_method_chain :valid?, :autosave_associations

        %w{ has_one belongs_to has_many has_and_belongs_to_many }.each do |type|
          base.send("valid_keys_for_#{type}_association") << :autosave
        end
      end
    end

    # Saves the parent, <tt>self</tt>, and any loaded autosave associations.
    # In addition, it destroys all children that were marked for destruction
    # with mark_for_destruction.
    #
    # This all happens inside a transaction, _if_ the Transactions module is included into
    # ActiveRecord::Base after the AutosaveAssociation module, which it does by default.
    def save_with_autosave_associations(perform_validation = true)
      returning(save_without_autosave_associations(perform_validation)) do |valid|
        if valid
          self.class.reflect_on_all_autosave_associations.each do |reflection|
            if (association = association_instance_get(reflection.name)) && association.loaded?
              if association.is_a?(Array)
                association.proxy_target.each do |child|
                  child.marked_for_destruction? ? child.destroy : child.save(perform_validation)
                end
              else
                association.marked_for_destruction? ? association.destroy : association.save(perform_validation)
              end
            end
          end
        end
      end
    end

    # Returns whether or not the parent, <tt>self</tt>, and any loaded autosave associations are valid.
    def valid_with_autosave_associations?
      if valid_without_autosave_associations?
        self.class.reflect_on_all_autosave_associations.all? do |reflection|
          if (association = association_instance_get(reflection.name)) && association.loaded?
            if association.is_a?(Array)
              association.proxy_target.all? { |child| autosave_association_valid?(reflection, child) }
            else
              autosave_association_valid?(reflection, association)
            end
          else
            true # association not loaded yet, so it should be valid
          end
        end
      else
        false # self was not valid
      end
    end

    # Returns whether or not the association is valid and applies any errors to the parent, <tt>self</tt>, if it wasn't.
    def autosave_association_valid?(reflection, association)
      returning(association.valid?) do |valid|
        association.errors.each do |attribute, message|
          errors.add "#{reflection.name}_#{attribute}", message
        end unless valid
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
  end
end