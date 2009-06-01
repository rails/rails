require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/object/try'

module ActiveRecord
  module NestedAttributes #:nodoc:
    extend ActiveSupport::Concern

    included do
      class_inheritable_accessor :reject_new_nested_attributes_procs, :instance_writer => false
      self.reject_new_nested_attributes_procs = {}
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
    #   params = { :member => { :name => 'Jack', :avatar_attributes => { :icon => 'smiling' } } }
    #   member = Member.create(params)
    #   member.avatar.id # => 2
    #   member.avatar.icon # => 'smiling'
    #
    # It also allows you to update the avatar through the member:
    #
    #   params = { :member' => { :avatar_attributes => { :id => '2', :icon => 'sad' } } }
    #   member.update_attributes params['member']
    #   member.avatar.icon # => 'sad'
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
    #   member.avatar_attributes = { :id => '2', :_delete => '1' }
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
    #     accepts_nested_attributes_for :posts
    #   end
    #
    # You can now set or update attributes on an associated post model through
    # the attribute hash.
    #
    # For each hash that does _not_ have an <tt>id</tt> key a new record will
    # be instantiated, unless the hash also contains a <tt>_delete</tt> key
    # that evaluates to +true+.
    #
    #   params = { :member => {
    #     :name => 'joe', :posts_attributes => [
    #       { :title => 'Kari, the awesome Ruby documentation browser!' },
    #       { :title => 'The egalitarian assumption of the modern citizen' },
    #       { :title => '', :_delete => '1' } # this will be ignored
    #     ]
    #   }}
    #
    #   member = Member.create(params['member'])
    #   member.posts.length # => 2
    #   member.posts.first.title # => 'Kari, the awesome Ruby documentation browser!'
    #   member.posts.second.title # => 'The egalitarian assumption of the modern citizen'
    #
    # You may also set a :reject_if proc to silently ignore any new record
    # hashes if they fail to pass your criteria. For example, the previous
    # example could be rewritten as:
    #
    #    class Member < ActiveRecord::Base
    #      has_many :posts
    #      accepts_nested_attributes_for :posts, :reject_if => proc { |attributes| attributes['title'].blank? }
    #    end
    #
    #   params = { :member => {
    #     :name => 'joe', :posts_attributes => [
    #       { :title => 'Kari, the awesome Ruby documentation browser!' },
    #       { :title => 'The egalitarian assumption of the modern citizen' },
    #       { :title => '' } # this will be ignored because of the :reject_if proc
    #     ]
    #   }}
    #
    #   member = Member.create(params['member'])
    #   member.posts.length # => 2
    #   member.posts.first.title # => 'Kari, the awesome Ruby documentation browser!'
    #   member.posts.second.title # => 'The egalitarian assumption of the modern citizen'
    #
    # If the hash contains an <tt>id</tt> key that matches an already
    # associated record, the matching record will be modified:
    #
    #   member.attributes = {
    #     :name => 'Joe',
    #     :posts_attributes => [
    #       { :id => 1, :title => '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!' },
    #       { :id => 2, :title => '[UPDATED] other post' }
    #     ]
    #   }
    #
    #   member.posts.first.title # => '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!'
    #   member.posts.second.title # => '[UPDATED] other post'
    #
    # By default the associated records are protected from being destroyed. If
    # you want to destroy any of the associated records through the attributes
    # hash, you have to enable it first using the <tt>:allow_destroy</tt>
    # option. This will allow you to also use the <tt>_delete</tt> key to
    # destroy existing records:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, :allow_destroy => true
    #   end
    #
    #   params = { :member => {
    #     :posts_attributes => [{ :id => '2', :_delete => '1' }]
    #   }}
    #
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
      # Defines an attributes writer for the specified association(s). If you
      # are using <tt>attr_protected</tt> or <tt>attr_accessible</tt>, then you
      # will need to add the attribute writer to the allowed list.
      #
      # Supported options:
      # [:allow_destroy]
      #   If true, destroys any members from the attributes hash with a
      #   <tt>_delete</tt> key and a value that evaluates to +true+
      #   (eg. 1, '1', true, or 'true'). This option is off by default.
      # [:reject_if]
      #   Allows you to specify a Proc that checks whether a record should be
      #   built for a certain attribute hash. The hash is passed to the Proc
      #   and the Proc should return either +true+ or +false+. When no Proc
      #   is specified a record will be built for all attribute hashes that
      #   do not have a <tt>_delete</tt> that evaluates to true.
      #   Passing <tt>:all_blank</tt> instead of a Proc will create a proc
      #   that will reject a record where all the attributes are blank.
      #
      # Examples:
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, :reject_if => proc { |attributes| attributes['name'].blank? }
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, :reject_if => :all_blank
      #   # creates avatar_attributes= and posts_attributes=
      #   accepts_nested_attributes_for :avatar, :posts, :allow_destroy => true
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

            self.reject_new_nested_attributes_procs[association_name.to_sym] = if options[:reject_if] == :all_blank
              proc { |attributes| attributes.all? {|k,v| v.blank?} }
            else
              options[:reject_if]
            end

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

    # Returns ActiveRecord::AutosaveAssociation::marked_for_destruction? It's
    # used in conjunction with fields_for to build a form element for the
    # destruction of this association.
    #
    # See ActionView::Helpers::FormHelper::fields_for for more info.
    def _delete
      marked_for_destruction?
    end

    private

    # Attribute hash keys that should not be assigned as normal attributes.
    # These hash keys are nested attributes implementation details.
    UNASSIGNABLE_KEYS = %w{ id _delete }

    # Assigns the given attributes to the association.
    #
    # If the given attributes include an <tt>:id</tt> that matches the existing
    # record’s id, then the existing record will be modified. Otherwise a new
    # record will be built.
    #
    # If the given attributes include a matching <tt>:id</tt> attribute _and_ a
    # <tt>:_delete</tt> key set to a truthy value, then the existing record
    # will be marked for destruction.
    def assign_nested_attributes_for_one_to_one_association(association_name, attributes, allow_destroy)
      attributes = attributes.stringify_keys

      if attributes['id'].blank?
        unless reject_new_record?(association_name, attributes)
          send("build_#{association_name}", attributes.except(*UNASSIGNABLE_KEYS))
        end
      elsif (existing_record = send(association_name)) && existing_record.id.to_s == attributes['id'].to_s
        assign_to_or_mark_for_destruction(existing_record, attributes, allow_destroy)
      end
    end

    # Assigns the given attributes to the collection association.
    #
    # Hashes with an <tt>:id</tt> value matching an existing associated record
    # will update that record. Hashes without an <tt>:id</tt> value will build
    # a new record for the association. Hashes with a matching <tt>:id</tt>
    # value and a <tt>:_delete</tt> key set to a truthy value will mark the
    # matched record for destruction.
    #
    # For example:
    #
    #   assign_nested_attributes_for_collection_association(:people, {
    #     '1' => { :id => '1', :name => 'Peter' },
    #     '2' => { :name => 'John' },
    #     '3' => { :id => '2', :_delete => true }
    #   })
    #
    # Will update the name of the Person with ID 1, build a new associated
    # person with the name `John', and mark the associated Person with ID 2
    # for destruction.
    #
    # Also accepts an Array of attribute hashes:
    #
    #   assign_nested_attributes_for_collection_association(:people, [
    #     { :id => '1', :name => 'Peter' },
    #     { :name => 'John' },
    #     { :id => '2', :_delete => true }
    #   ])
    def assign_nested_attributes_for_collection_association(association_name, attributes_collection, allow_destroy)
      unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
        raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
      end

      if attributes_collection.is_a? Hash
        attributes_collection = attributes_collection.sort_by { |index, _| index.to_i }.map { |_, attributes| attributes }
      end

      attributes_collection.each do |attributes|
        attributes = attributes.stringify_keys

        if attributes['id'].blank?
          unless reject_new_record?(association_name, attributes)
            send(association_name).build(attributes.except(*UNASSIGNABLE_KEYS))
          end
        elsif existing_record = send(association_name).detect { |record| record.id.to_s == attributes['id'].to_s }
          assign_to_or_mark_for_destruction(existing_record, attributes, allow_destroy)
        end
      end
    end

    # Updates a record with the +attributes+ or marks it for destruction if
    # +allow_destroy+ is +true+ and has_delete_flag? returns +true+.
    def assign_to_or_mark_for_destruction(record, attributes, allow_destroy)
      if has_delete_flag?(attributes) && allow_destroy
        record.mark_for_destruction
      else
        record.attributes = attributes.except(*UNASSIGNABLE_KEYS)
      end
    end

    # Determines if a hash contains a truthy _delete key.
    def has_delete_flag?(hash)
      ConnectionAdapters::Column.value_to_boolean hash['_delete']
    end

    # Determines if a new record should be build by checking for
    # has_delete_flag? or if a <tt>:reject_if</tt> proc exists for this
    # association and evaluates to +true+.
    def reject_new_record?(association_name, attributes)
      has_delete_flag?(attributes) ||
        self.class.reject_new_nested_attributes_procs[association_name].try(:call, attributes)
    end
  end
end
