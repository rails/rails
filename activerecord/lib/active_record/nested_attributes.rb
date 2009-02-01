module ActiveRecord
  module NestedAttributes #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
      base.class_inheritable_accessor :reject_new_nested_attributes_procs, :instance_writer => false
      base.reject_new_nested_attributes_procs = {}
    end

    # == Nested Attributes
    #
    # Nested attributes allow you to save attributes on associated records
    # through the parent. By default nested attribute updating is turned off,
    # you can enable it using the accepts_nested_attributes_for class method.
    # When you enable nested attributes an attribute writer is defined on
    # the model.
    #
    # The attribute writer is named after the association, which means that
    # in the following example, two new methods are added to your model:
    # <tt>author_attributes=(attributes)</tt> and
    # <tt>pages_attributes=(attributes)</tt>.
    #
    #   class Book < ActiveRecord::Base
    #     has_one :author
    #     has_many :pages
    #
    #     accepts_nested_attributes_for :author, :pages
    #   end
    #
    # Note that the <tt>:autosave</tt> option is automatically enabled on every
    # association that accepts_nested_attributes_for is used for.
    #
    # === One-to-one
    #
    # Consider a Member model that has one Avatar:
    #
    #   class Member < ActiveRecord::Base
    #     has_one :avatar
    #     accepts_nested_attributes_for :avatar
    #   end
    #
    # Enabling nested attributes on a one-to-one association allows you to
    # create the member and avatar in one go:
    #
    #   params = { 'member' => { 'name' => 'Jack', 'avatar_attributes' => { 'icon' => 'smiling' } } }
    #   member = Member.create(params)
    #   member.avatar.icon #=> 'smiling'
    #
    # It also allows you to update the avatar through the member:
    #
    #   params = { 'member' => { 'avatar_attributes' => { 'icon' => 'sad' } } }
    #   member.update_attributes params['member']
    #   member.avatar.icon #=> 'sad'
    #
    # By default you will only be able to set and update attributes on the
    # associated model. If you want to destroy the associated model through the
    # attributes hash, you have to enable it first using the
    # <tt>:allow_destroy</tt> option.
    #
    #   class Member < ActiveRecord::Base
    #     has_one :avatar
    #     accepts_nested_attributes_for :avatar, :allow_destroy => true
    #   end
    #
    # Now, when you add the <tt>_delete</tt> key to the attributes hash, with a
    # value that evaluates to +true+, you will destroy the associated model:
    #
    #   member.avatar_attributes = { '_delete' => '1' }
    #   member.avatar.marked_for_destruction? # => true
    #   member.save
    #   member.avatar #=> nil
    #
    # Note that the model will _not_ be destroyed until the parent is saved.
    #
    # === One-to-many
    #
    # Consider a member that has a number of posts:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, :reject_if => proc { |attributes| attributes['title'].blank? }
    #   end
    #
    # You can now set or update attributes on an associated post model through
    # the attribute hash.
    #
    # For each key in the hash that starts with the string 'new' a new model
    # will be instantiated. When the proc given with the <tt>:reject_if</tt>
    # option evaluates to +false+ for a certain attribute hash no record will
    # be built for that hash.
    #
    #   params = { 'member' => {
    #     'name' => 'joe', 'posts_attributes' => {
    #       'new_12345' => { 'title' => 'Kari, the awesome Ruby documentation browser!' },
    #       'new_54321' => { 'title' => 'The egalitarian assumption of the modern citizen' },
    #       'new_67890' => { 'title' => '' } # This one matches the :reject_if proc and will not be instantiated.
    #     }
    #   }}
    #
    #   member = Member.create(params['member'])
    #   member.posts.length #=> 2
    #   member.posts.first.title #=> 'Kari, the awesome Ruby documentation browser!'
    #   member.posts.second.title #=> 'The egalitarian assumption of the modern citizen'
    #
    # When the key for post attributes is an integer, the associated post with
    # that ID will be updated:
    #
    #   member.attributes = {
    #     'name' => 'Joe',
    #     'posts_attributes' => {
    #       '1' => { 'title' => '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!' },
    #       '2' => { 'title' => '[UPDATED] other post' }
    #     }
    #   }
    #
    # By default the associated models are protected from being destroyed. If
    # you want to destroy any of the associated models through the attributes
    # hash, you have to enable it first using the <tt>:allow_destroy</tt>
    # option.
    #
    # This will allow you to specify which models to destroy in the attributes
    # hash by setting the '_delete' attribute to a value that evaluates to
    # +true+:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, :allow_destroy => true
    #   end
    #
    #   params = {'member' => { 'name' => 'joe', 'posts_attributes' => {
    #     '2' => { '_delete' => '1' }
    #   }}}
    #   member.attributes = params['member']
    #   member.posts.detect { |p| p.id == 2 }.marked_for_destruction? # => true
    #   member.posts.length #=> 2
    #   member.save
    #   member.posts.length # => 1
    #
    # === Saving
    #
    # All changes to models, including the destruction of those marked for
    # destruction, are saved and destroyed automatically and atomically when
    # the parent model is saved. This happens inside the transaction initiated
    # by the parents save method. See ActiveRecord::AutosaveAssociation.
    module ClassMethods
      # Defines an attributes writer for the specified association(s).
      #
      # Supported options:
      # [:allow_destroy]
      #   If true, destroys any members from the attributes hash with a
      #   <tt>_delete</tt> key and a value that converts to +true+
      #   (eg. 1, '1', true, or 'true'). This option is off by default.
      # [:reject_if]
      #   Allows you to specify a Proc that checks whether a record should be
      #   built for a certain attribute hash. The hash is passed to the Proc
      #   and the Proc should return either +true+ or +false+. When no Proc
      #   is specified a record will be built for all attribute hashes.
      #
      # Examples:
      #   accepts_nested_attributes_for :avatar
      #   accepts_nested_attributes_for :avatar, :allow_destroy => true
      #   accepts_nested_attributes_for :avatar, :reject_if => proc { ... }
      #   accepts_nested_attributes_for :avatar, :posts, :allow_destroy => true, :reject_if => proc { ... }
      def accepts_nested_attributes_for(*attr_names)
        options = { :allow_destroy => false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if)

        attr_names.each do |association_name|
          if reflection = reflect_on_association(association_name)
            type = case reflection.macro
            when :has_one, :belongs_to
              :one_to_one
            when :has_many, :has_and_belongs_to_many
              :collection
            end

            reflection.options[:autosave] = true
            self.reject_new_nested_attributes_procs[association_name.to_sym] = options[:reject_if]

            # def pirate_attributes=(attributes)
            #   assign_nested_attributes_for_one_to_one_association(:pirate, attributes, false)
            # end
            class_eval %{
              def #{association_name}_attributes=(attributes)
                assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes, #{options[:allow_destroy]})
              end
            }, __FILE__, __LINE__
          else
            raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
          end
        end
      end
    end

    # Returns ActiveRecord::AutosaveAssociation::marked_for_destruction?
    # It's used in conjunction with fields_for to build a form element
    # for the destruction of this association.
    #
    # See ActionView::Helpers::FormHelper::fields_for for more info.
    def _delete
      marked_for_destruction?
    end

    private

    # Assigns the given attributes to the association. An association will be
    # build if it doesn't exist yet.
    def assign_nested_attributes_for_one_to_one_association(association_name, attributes, allow_destroy)
      if should_destroy_nested_attributes_record?(allow_destroy, attributes)
        send(association_name).mark_for_destruction
      else
        (send(association_name) || send("build_#{association_name}")).attributes = attributes
      end
    end

    # Assigns the given attributes to the collection association.
    #
    # Keys containing an ID for an associated record will update that record.
    # Keys starting with <tt>new</tt> will instantiate a new record for that
    # association.
    #
    # For example:
    #
    #   assign_nested_attributes_for_collection_association(:people, {
    #     '1' => { 'name' => 'Peter' },
    #     'new_43' => { 'name' => 'John' }
    #   })
    #
    # Will update the name of the Person with ID 1 and create a new associated
    # person with the name 'John'.
    def assign_nested_attributes_for_collection_association(association_name, attributes, allow_destroy)
      unless attributes.is_a?(Hash)
        raise ArgumentError, "Hash expected, got #{attributes.class.name} (#{attributes.inspect})"
      end

      # Make sure any new records sorted by their id before they're build.
      sorted_by_id = attributes.sort_by { |id, _| id.is_a?(String) ? id.sub(/^new_/, '').to_i : id }

      sorted_by_id.each do |id, record_attributes|
        if id.acts_like?(:string) && id.starts_with?('new_')
          build_new_nested_attributes_record(association_name, record_attributes)
        else
          assign_to_or_destroy_nested_attributes_record(association_name, id, record_attributes, allow_destroy)
        end
      end
    end

    # Returns +true+ if <tt>allow_destroy</tt> is enabled and the attributes
    # contains a truthy value for the key <tt>'_delete'</tt>.
    #
    # It will _always_ remove the <tt>'_delete'</tt> key, if present.
    def should_destroy_nested_attributes_record?(allow_destroy, attributes)
      ConnectionAdapters::Column.value_to_boolean(attributes.delete('_delete')) && allow_destroy
    end

    # Builds a new record with the given attributes.
    #
    # If a <tt>:reject_if</tt> proc exists for this association, it will be
    # called with the attributes as its argument. If the proc returns a truthy
    # value, the record is _not_ build.
    def build_new_nested_attributes_record(association_name, attributes)
      if reject_proc = self.class.reject_new_nested_attributes_procs[association_name]
        return if reject_proc.call(attributes)
      end
      send(association_name).build(attributes)
    end

    # Assigns the attributes to the record specified by +id+. Or marks it for
    # destruction if #should_destroy_nested_attributes_record? returns +true+.
    def assign_to_or_destroy_nested_attributes_record(association_name, id, attributes, allow_destroy)
      record = send(association_name).detect { |record| record.id == id.to_i }
      if should_destroy_nested_attributes_record?(allow_destroy, attributes)
        record.mark_for_destruction
      else
        record.attributes = attributes
      end
    end
  end
end