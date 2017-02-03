require "active_support/core_ext/hash/except"
require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/indifferent_access"

module ActiveRecord
  module NestedAttributes #:nodoc:
    class TooManyRecords < ActiveRecordError
    end

    extend ActiveSupport::Concern

    included do
      class_attribute :nested_attributes_options, instance_writer: false
      self.nested_attributes_options = {}
    end

    # = Active Record Nested Attributes
    #
    # Nested attributes allow you to save attributes on associated records
    # through the parent. By default nested attribute updating is turned off
    # and you can enable it using the accepts_nested_attributes_for class
    # method. When you enable nested attributes an attribute writer is
    # defined on the model.
    #
    # The attribute writer is named after the association, which means that
    # in the following example, two new methods are added to your model:
    #
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
    #   params = { member: { name: 'Jack', avatar_attributes: { icon: 'smiling' } } }
    #   member = Member.create(params[:member])
    #   member.avatar.id # => 2
    #   member.avatar.icon # => 'smiling'
    #
    # It also allows you to update the avatar through the member:
    #
    #   params = { member: { avatar_attributes: { id: '2', icon: 'sad' } } }
    #   member.update params[:member]
    #   member.avatar.icon # => 'sad'
    #
    # By default you will only be able to set and update attributes on the
    # associated model. If you want to destroy the associated model through the
    # attributes hash, you have to enable it first using the
    # <tt>:allow_destroy</tt> option.
    #
    #   class Member < ActiveRecord::Base
    #     has_one :avatar
    #     accepts_nested_attributes_for :avatar, allow_destroy: true
    #   end
    #
    # Now, when you add the <tt>_destroy</tt> key to the attributes hash, with a
    # value that evaluates to +true+, you will destroy the associated model:
    #
    #   member.avatar_attributes = { id: '2', _destroy: '1' }
    #   member.avatar.marked_for_destruction? # => true
    #   member.save
    #   member.reload.avatar # => nil
    #
    # Note that the model will _not_ be destroyed until the parent is saved.
    #
    # Also note that the model will not be destroyed unless you also specify
    # its id in the updated hash.
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
    # You can now set or update attributes on the associated posts through
    # an attribute hash for a member: include the key +:posts_attributes+
    # with an array of hashes of post attributes as a value.
    #
    # For each hash that does _not_ have an <tt>id</tt> key a new record will
    # be instantiated, unless the hash also contains a <tt>_destroy</tt> key
    # that evaluates to +true+.
    #
    #   params = { member: {
    #     name: 'joe', posts_attributes: [
    #       { title: 'Kari, the awesome Ruby documentation browser!' },
    #       { title: 'The egalitarian assumption of the modern citizen' },
    #       { title: '', _destroy: '1' } # this will be ignored
    #     ]
    #   }}
    #
    #   member = Member.create(params[:member])
    #   member.posts.length # => 2
    #   member.posts.first.title # => 'Kari, the awesome Ruby documentation browser!'
    #   member.posts.second.title # => 'The egalitarian assumption of the modern citizen'
    #
    # You may also set a +:reject_if+ proc to silently ignore any new record
    # hashes if they fail to pass your criteria. For example, the previous
    # example could be rewritten as:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, reject_if: proc { |attributes| attributes['title'].blank? }
    #   end
    #
    #   params = { member: {
    #     name: 'joe', posts_attributes: [
    #       { title: 'Kari, the awesome Ruby documentation browser!' },
    #       { title: 'The egalitarian assumption of the modern citizen' },
    #       { title: '' } # this will be ignored because of the :reject_if proc
    #     ]
    #   }}
    #
    #   member = Member.create(params[:member])
    #   member.posts.length # => 2
    #   member.posts.first.title # => 'Kari, the awesome Ruby documentation browser!'
    #   member.posts.second.title # => 'The egalitarian assumption of the modern citizen'
    #
    # Alternatively, +:reject_if+ also accepts a symbol for using methods:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, reject_if: :new_record?
    #   end
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, reject_if: :reject_posts
    #
    #     def reject_posts(attributes)
    #       attributes['title'].blank?
    #     end
    #   end
    #
    # If the hash contains an <tt>id</tt> key that matches an already
    # associated record, the matching record will be modified:
    #
    #   member.attributes = {
    #     name: 'Joe',
    #     posts_attributes: [
    #       { id: 1, title: '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!' },
    #       { id: 2, title: '[UPDATED] other post' }
    #     ]
    #   }
    #
    #   member.posts.first.title # => '[UPDATED] An, as of yet, undisclosed awesome Ruby documentation browser!'
    #   member.posts.second.title # => '[UPDATED] other post'
    #
    # However, the above applies if the parent model is being updated as well.
    # For example, If you wanted to create a +member+ named _joe_ and wanted to
    # update the +posts+ at the same time, that would give an
    # ActiveRecord::RecordNotFound error.
    #
    # By default the associated records are protected from being destroyed. If
    # you want to destroy any of the associated records through the attributes
    # hash, you have to enable it first using the <tt>:allow_destroy</tt>
    # option. This will allow you to also use the <tt>_destroy</tt> key to
    # destroy existing records:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts
    #     accepts_nested_attributes_for :posts, allow_destroy: true
    #   end
    #
    #   params = { member: {
    #     posts_attributes: [{ id: '2', _destroy: '1' }]
    #   }}
    #
    #   member.attributes = params[:member]
    #   member.posts.detect { |p| p.id == 2 }.marked_for_destruction? # => true
    #   member.posts.length # => 2
    #   member.save
    #   member.reload.posts.length # => 1
    #
    # Nested attributes for an associated collection can also be passed in
    # the form of a hash of hashes instead of an array of hashes:
    #
    #   Member.create(
    #     name: 'joe',
    #     posts_attributes: {
    #       first:  { title: 'Foo' },
    #       second: { title: 'Bar' }
    #     }
    #   )
    #
    # has the same effect as
    #
    #   Member.create(
    #     name: 'joe',
    #     posts_attributes: [
    #       { title: 'Foo' },
    #       { title: 'Bar' }
    #     ]
    #   )
    #
    # The keys of the hash which is the value for +:posts_attributes+ are
    # ignored in this case.
    # However, it is not allowed to use <tt>'id'</tt> or <tt>:id</tt> for one of
    # such keys, otherwise the hash will be wrapped in an array and
    # interpreted as an attribute hash for a single post.
    #
    # Passing attributes for an associated collection in the form of a hash
    # of hashes can be used with hashes generated from HTTP/HTML parameters,
    # where there may be no natural way to submit an array of hashes.
    #
    # === Saving
    #
    # All changes to models, including the destruction of those marked for
    # destruction, are saved and destroyed automatically and atomically when
    # the parent model is saved. This happens inside the transaction initiated
    # by the parent's save method. See ActiveRecord::AutosaveAssociation.
    #
    # === Validating the presence of a parent model
    #
    # If you want to validate that a child record is associated with a parent
    # record, you can use the +validates_presence_of+ method and the +:inverse_of+
    # key as this example illustrates:
    #
    #   class Member < ActiveRecord::Base
    #     has_many :posts, inverse_of: :member
    #     accepts_nested_attributes_for :posts
    #   end
    #
    #   class Post < ActiveRecord::Base
    #     belongs_to :member, inverse_of: :posts
    #     validates_presence_of :member
    #   end
    #
    # Note that if you do not specify the +:inverse_of+ option, then
    # Active Record will try to automatically guess the inverse association
    # based on heuristics.
    #
    # For one-to-one nested associations, if you build the new (in-memory)
    # child object yourself before assignment, then this module will not
    # overwrite it, e.g.:
    #
    #   class Member < ActiveRecord::Base
    #     has_one :avatar
    #     accepts_nested_attributes_for :avatar
    #
    #     def avatar
    #       super || build_avatar(width: 200)
    #     end
    #   end
    #
    #   member = Member.new
    #   member.avatar_attributes = {icon: 'sad'}
    #   member.avatar.width # => 200
    module ClassMethods
      REJECT_ALL_BLANK_PROC = proc { |attributes| attributes.all? { |key, value| key == "_destroy" || value.blank? } }

      # Defines an attributes writer for the specified association(s).
      #
      # Supported options:
      # [:allow_destroy]
      #   If true, destroys any members from the attributes hash with a
      #   <tt>_destroy</tt> key and a value that evaluates to +true+
      #   (eg. 1, '1', true, or 'true'). This option is off by default.
      # [:reject_if]
      #   Allows you to specify a Proc or a Symbol pointing to a method
      #   that checks whether a record should be built for a certain attribute
      #   hash. The hash is passed to the supplied Proc or the method
      #   and it should return either +true+ or +false+. When no +:reject_if+
      #   is specified, a record will be built for all attribute hashes that
      #   do not have a <tt>_destroy</tt> value that evaluates to true.
      #   Passing <tt>:all_blank</tt> instead of a Proc will create a proc
      #   that will reject a record where all the attributes are blank excluding
      #   any value for +_destroy+.
      # [:limit]
      #   Allows you to specify the maximum number of associated records that
      #   can be processed with the nested attributes. Limit also can be specified
      #   as a Proc or a Symbol pointing to a method that should return a number.
      #   If the size of the nested attributes array exceeds the specified limit,
      #   NestedAttributes::TooManyRecords exception is raised. If omitted, any
      #   number of associations can be processed.
      #   Note that the +:limit+ option is only applicable to one-to-many
      #   associations.
      # [:update_only]
      #   For a one-to-one association, this option allows you to specify how
      #   nested attributes are going to be used when an associated record already
      #   exists. In general, an existing record may either be updated with the
      #   new set of attribute values or be replaced by a wholly new record
      #   containing those values. By default the +:update_only+ option is +false+
      #   and the nested attributes are used to update the existing record only
      #   if they include the record's <tt>:id</tt> value. Otherwise a new
      #   record will be instantiated and used to replace the existing one.
      #   However if the +:update_only+ option is +true+, the nested attributes
      #   are used to update the record's attributes always, regardless of
      #   whether the <tt>:id</tt> is present. The option is ignored for collection
      #   associations.
      #
      # Examples:
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, reject_if: proc { |attributes| attributes['name'].blank? }
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, reject_if: :all_blank
      #   # creates avatar_attributes= and posts_attributes=
      #   accepts_nested_attributes_for :avatar, :posts, allow_destroy: true
      def accepts_nested_attributes_for(*attr_names)
        options = { allow_destroy: false, update_only: false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only)
        options[:reject_if] = REJECT_ALL_BLANK_PROC if options[:reject_if] == :all_blank

        attr_names.each do |association_name|
          if reflection = _reflect_on_association(association_name)
            reflection.autosave = true
            define_autosave_validation_callbacks(reflection)

            nested_attributes_options = self.nested_attributes_options.dup
            nested_attributes_options[association_name.to_sym] = options
            self.nested_attributes_options = nested_attributes_options

            type = (reflection.collection? ? :collection : :one_to_one)
            generate_association_writer(association_name, type)
          else
            raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
          end
        end
      end

      private

        # Generates a writer method for this association. Serves as a point for
        # accessing the objects in the association. For example, this method
        # could generate the following:
        #
        #   def pirate_attributes=(attributes)
        #     assign_nested_attributes_for_one_to_one_association(:pirate, attributes)
        #   end
        #
        # This redirects the attempts to write objects in an association through
        # the helper methods defined below. Makes it seem like the nested
        # associations are just regular associations.
        def generate_association_writer(association_name, type)
          generated_association_methods.module_eval <<-eoruby, __FILE__, __LINE__ + 1
            if method_defined?(:#{association_name}_attributes=)
              remove_method(:#{association_name}_attributes=)
            end
            def #{association_name}_attributes=(attributes)
              assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes)
            end
          eoruby
        end
    end

    # Returns ActiveRecord::AutosaveAssociation::marked_for_destruction? It's
    # used in conjunction with fields_for to build a form element for the
    # destruction of this association.
    #
    # See ActionView::Helpers::FormHelper::fields_for for more info.
    def _destroy
      marked_for_destruction?
    end

    private

      # Attribute hash keys that should not be assigned as normal attributes.
      # These hash keys are nested attributes implementation details.
      UNASSIGNABLE_KEYS = %w( id _destroy )

      # Assigns the given attributes to the association.
      #
      # If an associated record does not yet exist, one will be instantiated. If
      # an associated record already exists, the method's behavior depends on
      # the value of the update_only option. If update_only is +false+ and the
      # given attributes include an <tt>:id</tt> that matches the existing record's
      # id, then the existing record will be modified. If no <tt>:id</tt> is provided
      # it will be replaced with a new record. If update_only is +true+ the existing
      # record will be modified regardless of whether an <tt>:id</tt> is provided.
      #
      # If the given attributes include a matching <tt>:id</tt> attribute, or
      # update_only is true, and a <tt>:_destroy</tt> key set to a truthy value,
      # then the existing record will be marked for destruction.
      def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
        options = nested_attributes_options[association_name]
        if attributes.respond_to?(:permitted?)
          attributes = attributes.to_h
        end
        attributes = attributes.with_indifferent_access
        existing_record = send(association_name)

        if (options[:update_only] || !attributes["id"].blank?) && existing_record &&
            (options[:update_only] || existing_record.id.to_s == attributes["id"].to_s)
          assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy]) unless call_reject_if(association_name, attributes)

        elsif attributes["id"].present?
          raise_nested_attributes_record_not_found!(association_name, attributes["id"])

        elsif !reject_new_record?(association_name, attributes)
          assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

          if existing_record && existing_record.new_record?
            existing_record.assign_attributes(assignable_attributes)
            association(association_name).initialize_attributes(existing_record)
          else
            method = "build_#{association_name}"
            if respond_to?(method)
              send(method, assignable_attributes)
            else
              raise ArgumentError, "Cannot build association `#{association_name}'. Are you trying to build a polymorphic one-to-one association?"
            end
          end
        end
      end

      # Assigns the given attributes to the collection association.
      #
      # Hashes with an <tt>:id</tt> value matching an existing associated record
      # will update that record. Hashes without an <tt>:id</tt> value will build
      # a new record for the association. Hashes with a matching <tt>:id</tt>
      # value and a <tt>:_destroy</tt> key set to a truthy value will mark the
      # matched record for destruction.
      #
      # For example:
      #
      #   assign_nested_attributes_for_collection_association(:people, {
      #     '1' => { id: '1', name: 'Peter' },
      #     '2' => { name: 'John' },
      #     '3' => { id: '2', _destroy: true }
      #   })
      #
      # Will update the name of the Person with ID 1, build a new associated
      # person with the name 'John', and mark the associated Person with ID 2
      # for destruction.
      #
      # Also accepts an Array of attribute hashes:
      #
      #   assign_nested_attributes_for_collection_association(:people, [
      #     { id: '1', name: 'Peter' },
      #     { name: 'John' },
      #     { id: '2', _destroy: true }
      #   ])
      def assign_nested_attributes_for_collection_association(association_name, attributes_collection)
        options = nested_attributes_options[association_name]
        if attributes_collection.respond_to?(:permitted?)
          attributes_collection = attributes_collection.to_h
        end

        unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
          raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
        end

        check_record_limit!(options[:limit], attributes_collection)

        if attributes_collection.is_a? Hash
          keys = attributes_collection.keys
          attributes_collection = if keys.include?("id") || keys.include?(:id)
            [attributes_collection]
          else
            attributes_collection.values
          end
        end

        association = association(association_name)

        existing_records = if association.loaded?
          association.target
        else
          attribute_ids = attributes_collection.map { |a| a["id"] || a[:id] }.compact
          attribute_ids.empty? ? [] : association.scope.where(association.klass.primary_key => attribute_ids)
        end

        attributes_collection.each do |attributes|
          if attributes.respond_to?(:permitted?)
            attributes = attributes.to_h
          end
          attributes = attributes.with_indifferent_access

          if attributes["id"].blank?
            unless reject_new_record?(association_name, attributes)
              association.build(attributes.except(*UNASSIGNABLE_KEYS))
            end
          elsif existing_record = existing_records.detect { |record| record.id.to_s == attributes["id"].to_s }
            unless call_reject_if(association_name, attributes)
              # Make sure we are operating on the actual object which is in the association's
              # proxy_target array (either by finding it, or adding it if not found)
              # Take into account that the proxy_target may have changed due to callbacks
              target_record = association.target.detect { |record| record.id.to_s == attributes["id"].to_s }
              if target_record
                existing_record = target_record
              else
                association.add_to_target(existing_record, :skip_callbacks)
              end

              assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])
            end
          else
            raise_nested_attributes_record_not_found!(association_name, attributes["id"])
          end
        end
      end

      # Takes in a limit and checks if the attributes_collection has too many
      # records. It accepts limit in the form of symbol, proc, or
      # number-like object (anything that can be compared with an integer).
      #
      # Raises TooManyRecords error if the attributes_collection is
      # larger than the limit.
      def check_record_limit!(limit, attributes_collection)
        if limit
          limit = \
            case limit
            when Symbol
              send(limit)
            when Proc
              limit.call
            else
              limit
            end

          if limit && attributes_collection.size > limit
            raise TooManyRecords, "Maximum #{limit} records are allowed. Got #{attributes_collection.size} records instead."
          end
        end
      end

      # Updates a record with the +attributes+ or marks it for destruction if
      # +allow_destroy+ is +true+ and has_destroy_flag? returns +true+.
      def assign_to_or_mark_for_destruction(record, attributes, allow_destroy)
        record.assign_attributes(attributes.except(*UNASSIGNABLE_KEYS))
        record.mark_for_destruction if has_destroy_flag?(attributes) && allow_destroy
      end

      # Determines if a hash contains a truthy _destroy key.
      def has_destroy_flag?(hash)
        Type::Boolean.new.cast(hash["_destroy"])
      end

      # Determines if a new record should be rejected by checking
      # has_destroy_flag? or if a <tt>:reject_if</tt> proc exists for this
      # association and evaluates to +true+.
      def reject_new_record?(association_name, attributes)
        will_be_destroyed?(association_name, attributes) || call_reject_if(association_name, attributes)
      end

      # Determines if a record with the particular +attributes+ should be
      # rejected by calling the reject_if Symbol or Proc (if defined).
      # The reject_if option is defined by +accepts_nested_attributes_for+.
      #
      # Returns false if there is a +destroy_flag+ on the attributes.
      def call_reject_if(association_name, attributes)
        return false if will_be_destroyed?(association_name, attributes)

        case callback = nested_attributes_options[association_name][:reject_if]
        when Symbol
          method(callback).arity == 0 ? send(callback) : send(callback, attributes)
        when Proc
          callback.call(attributes)
        end
      end

      # Only take into account the destroy flag if <tt>:allow_destroy</tt> is true
      def will_be_destroyed?(association_name, attributes)
        allow_destroy?(association_name) && has_destroy_flag?(attributes)
      end

      def allow_destroy?(association_name)
        nested_attributes_options[association_name][:allow_destroy]
      end

      def raise_nested_attributes_record_not_found!(association_name, record_id)
        model = self.class._reflect_on_association(association_name).klass.name
        raise RecordNotFound.new("Couldn't find #{model} with ID=#{record_id} for #{self.class.name} with ID=#{id}",
                                 model, "id", record_id)
      end
  end
end
