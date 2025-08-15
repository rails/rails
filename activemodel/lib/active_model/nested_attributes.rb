# frozen_string_literal: true

require "active_support/core_ext/hash/except"
require "active_support/inflector"
require "active_support/hash_with_indifferent_access"

module ActiveModel
  module NestedAttributes
    extend ActiveSupport::Concern

    class TooManyModels < ArgumentError
    end

    included do
      class_attribute :nested_attributes_options, instance_writer: false, default: {}
    end

    # = Active Model Nested \Attributes
    #
    # Nested attributes allow you to write attributes on associated models
    # through the parent. By default nested attribute writing is turned off
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
    #   class Book
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :author
    #     attr_accessor :pages
    #
    #     accepts_nested_attributes_for :author, class_name: Author
    #     accepts_nested_attributes_for :pages, class_name: Page
    #   end
    #
    # === One-to-one
    #
    # Consider a Member model that has an +:avatar+ attribute:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :avatar
    #     accepts_nested_attributes_for :avatar, class_name: Avatar
    #   end
    #
    # Enabling nested attributes on a one-to-one association allows you to
    # create the member and avatar in one go:
    #
    #   params = { member: { name: "Jack", avatar_attributes: { icon: "smiling" } } }
    #   member = Member.new(params[:member])
    #   member.name # => "Jack"
    #   member.avatar.icon # => "smiling"
    #
    # It also allows you to write to the avatar through the member:
    #
    #   params = { member: { avatar_attributes: { id: "2", icon: "sad" } } }
    #   member.assign_attributes params[:member]
    #   member.avatar.icon # => "sad"
    #
    # Note When defining nested attributes defined through +attr_accessor+ or
    # +attr_write+, Active Model will infer a one-to-one relationship for
    # singular attribute names. To force a one-to-one relationship, pass
    # <tt>array: false</tt>:
    #
    #   class Shepherd
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :sheep
    #     accepts_nested_attributes_for :sheep, array: false, class_name: Sheep
    #   end
    #
    # If you omit the <tt>:class_name</tt> option, the class is responsible
    # for defining a method to build instances from the attributes. In the
    # case of this example, the Member class must define a
    # <tt>build_avatar</tt> method:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :avatar
    #     accepts_nested_attributes_for :avatar
    #
    #     def build_avatar(attributes)
    #       Avatar.new(attributes)
    #     end
    #   end
    #
    # Note that the presence of a <tt>build_</tt>-prefixed method will have
    # precedent over a <tt>:class_name</tt> option when both are available.
    #
    # By default you will only be able to set attributes on the
    # associated model. If you want to destroy the associated model through the
    # attributes hash, you have to enable it first using the
    # <tt>:allow_destroy</tt> option.
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :avatar
    #     accepts_nested_attributes_for :avatar, class_name: Avatar, allow_destroy: true
    #   end
    #
    # Now, when you add the <tt>_destroy</tt> key to the attributes hash, with a
    # value that evaluates to +true+, you will unassign the associated model:
    #
    #   member.avatar_attributes = { _destroy: "1" }
    #   member.avatar # => nil
    #
    # If you add the <tt>_destroy</tt> key to the attributes hash and the
    # assigned instance responds to <tt>mark_for_destruction?</tt>, assignment
    # will call that method on the associated model:
    #
    #   member.avatar_attributes = { _destroy: "1" }
    #   member.avatar.marked_for_destruction? # => true
    #
    # Note that the model will _not_ be unassigned automatically. It is the
    # parent's responsibility to remove models marked for destruction.
    #
    # You may also set a +:reject_if+ proc to silently ignore any new record
    # hashes if they fail to pass your criteria. For example, the previous
    # example could be rewritten as:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :avatar
    #     accepts_nested_attributes_for :avatar, class_name: Avatar,
    #       reject_if: proc { |attributes| attributes["icon"].blank? }
    #   end
    #
    #   params = { member: { name: "joe", avatar_attributes: { icon: "" } } }
    #
    #   member = Member.new(params[:member])
    #   member.icon # => nil
    #
    # Alternatively, +:reject_if+ also accepts a symbol for using methods:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :avatar
    #     accepts_nested_attributes_for :avatar, class_name: Avatar,
    #       reject_if: :reject_avatar
    #
    #     def reject_avatar(attributes)
    #       attributes["icon"].blank?
    #     end
    #   end
    #
    # === One-to-many
    #
    # Consider a member that has a number of posts:
    #
    #   class Member < ActiveRecord::Base
    #     attr_accessor :posts
    #     accepts_nested_attributes_for :posts, class_name: Post
    #   end
    #
    # You can now set attributes on the associated posts through
    # an attribute hash for a member: include the key +:posts_attributes+
    # with an array of hashes of post attributes as a value.
    #
    # For each hash a new model will be instantiated, unless the hash also
    # contains a <tt>_destroy</tt> key that evaluates to +true+.
    #
    #   params = { member: {
    #     name: "joe", posts_attributes: [
    #       { title: "Kari, the awesome Ruby documentation browser!" },
    #       { title: "The egalitarian assumption of the modern citizen" },
    #       { title: "", _destroy: "1" } # this will be ignored
    #     ]
    #   }}
    #
    #   member = Member.new(params[:member])
    #   member.posts.length # => 2
    #   member.posts.first.title # => "Kari, the awesome Ruby documentation browser!"
    #   member.posts.second.title # => "The egalitarian assumption of the modern citizen"
    #
    # You may also set a +:reject_if+ proc to silently ignore any new model
    # hashes if they fail to pass your criteria. For example, the previous
    # example could be rewritten as:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :posts
    #     accepts_nested_attributes_for :posts, class_name: Post,
    #       reject_if: proc { |attributes| attributes["title"].blank? }
    #   end
    #
    #   params = { member: {
    #     name: "joe", posts_attributes: [
    #       { title: "Kari, the awesome Ruby documentation browser!" },
    #       { title: "The egalitarian assumption of the modern citizen" },
    #       { title: "" } # this will be ignored because of the :reject_if proc
    #     ]
    #   }}
    #
    #   member = Member.new(params[:member])
    #   member.posts.length # => 2
    #   member.posts.first.title # => "Kari, the awesome Ruby documentation browser!"
    #   member.posts.second.title # => "The egalitarian assumption of the modern citizen"
    #
    # Alternatively, +:reject_if+ also accepts a symbol for using methods:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :posts
    #     accepts_nested_attributes_for :posts, reject_if: :reject_posts
    #
    #     def reject_posts(attributes)
    #       attributes["title"].blank?
    #     end
    #   end
    #
    # By default the associated models are protected from being destroyed. If
    # you want to destroy any of the associated models through the attributes
    # hash, you have to enable it first using the <tt>:allow_destroy</tt>
    # option. This will allow you to also use the <tt>_destroy</tt> key to
    # destroy existing models:
    #
    #   class Member
    #     include ActiveModel::Model
    #     include ActiveModel::NestedAttributes
    #
    #     attr_accessor :posts
    #     accepts_nested_attributes_for :posts, class_name: Post, allow_destroy: true
    #   end
    #
    #   params = { member: {
    #     posts_attributes: [{ _destroy: "1" }]
    #   }}
    #
    #   member.attributes = params[:member]
    #   member.posts.length # => 0
    #
    # If you add the <tt>_destroy</tt> key to the attributes hash and the
    # assigned instances respond to <tt>mark_for_destruction?</tt>, assignment
    # will call that method on the associated models:
    #
    #   params = { member: {
    #     posts_attributes: [{ _destroy: "1" }]
    #   }}
    #   member.posts.length # => 1
    #   member.posts.first.marked_for_destruction? # => true
    #
    # Note that the models will _not_ be unassigned automatically. It is the
    # parent's responsibility to remove models marked for destruction.
    #
    # Nested attributes for an associated collection can also be passed in
    # the form of a hash of hashes instead of an array of hashes:
    #
    #   Member.new(
    #     name: "joe",
    #     posts_attributes: {
    #       first:  { title: "Foo" },
    #       second: { title: "Bar" }
    #     }
    #   )
    #
    # has the same effect as
    #
    #   Member.new(
    #     name: "joe",
    #     posts_attributes: [
    #       { title: "Foo" },
    #       { title: "Bar" }
    #     ]
    #   )
    #
    # The keys of the hash which is the value for +:posts_attributes+ are
    # ignored in this case.
    #
    # Passing attributes for an associated collection in the form of a hash
    # of hashes can be used with hashes generated from HTTP/HTML parameters,
    # where there may be no natural way to submit an array of hashes.
    #
    # === Integration with ActiveModel::Attributes
    #
    # When attributes are declared with the +.attribute+ class method provided
    # by the Attributes module, support
    # for nested attributes will construct instances using available
    # Type information. For example, the +accepts_nested_attributes_for+
    # declarations in the following code sample will use the Type that corresponds
    # to +:user+ when assigning to +author_attributes+ and the Type that
    # correpsonds to +:tags+ when assigning to +tags_attributes+:
    #
    #   class Article
    #     include ActiveModel::Model
    #     include ActiveModel::Attributes
    #     include ActiveModel::NestedAttributes
    #
    #     attribute :author, :user
    #     attribute :tags, :tag
    #
    #     accepts_nested_attributes_for :author
    #     accepts_nested_attributes_for :tags
    #   end
    #
    #   article = Article.new(
    #     author_attributes: { name: "Pseudo Nym" },
    #     tags_attributes: {
    #       "0" => { name: "actionpack" },
    #       "1" => { name: "actionview" },
    #     }
    #   )
    #   article.author.class # => User
    #   article.tags.map(&:class) # => [Tag, Tag]
    #
    # === Creating forms with nested attributes
    #
    # Use ActionView::Helpers::FormHelper#fields_for to create form elements for
    # nested attributes.
    #
    # Integration test params should reflect the structure of the form. For
    # example:
    #
    #   post members_path, params: {
    #     member: {
    #       name: "joe",
    #       posts_attributes: {
    #         "0" => { title: "Foo" },
    #         "1" => { title: "Bar" }
    #       }
    #     }
    #   }
    module ClassMethods
      REJECT_ALL_BLANK_PROC = proc { |attributes| attributes.all? { |key, value| key == "_destroy" || value.blank? } }

      # Defines an attributes writer for the specified model(s).
      #
      # Supported options:
      # [:allow_destroy]
      #   If true, destroys any members from the attributes hash with a
      #   <tt>_destroy</tt> key and a value that evaluates to +true+ (e.g. 1,
      #   "1", true, or "true"). If the model responds to
      #   <tt>mark_for_destruction</tt>, assignment will call that method and
      #   the member will not be omitted assigned to +nil+. If the model does
      #   not respond to <tt>mark_for_destruction</tt>, it will be omitted from
      #   a collection or assigned to +nil+. This option is +false+ by default.
      # [:reject_if]
      #   Allows you to specify a Proc or a Symbol pointing to a method
      #   that checks whether a model should be built for a certain attribute
      #   hash. The hash is passed to the supplied Proc or the method
      #   and it should return either +true+ or +false+. When no +:reject_if+
      #   is specified, a model will be built for all attribute hashes that
      #   do not have a <tt>_destroy</tt> value that evaluates to true.
      #   Passing <tt>:all_blank</tt> instead of a Proc will create a proc
      #   that will reject a model where all the attributes are blank excluding
      #   any value for +_destroy+.
      # [:limit]
      #   Allows you to specify the maximum number of associated model that
      #   can be processed with the nested attributes. Limit also can be specified
      #   as a Proc or a Symbol pointing to a method that should return a number.
      #   If the size of the nested attributes array exceeds the specified limit,
      #   NestedAttributes::TooManyRecords exception is raised. If omitted, any
      #   number of associations can be processed.
      #   Note that the +:limit+ option is only applicable to one-to-many
      #   associations.
      # [:class_name]
      #   Instructs the model on how to transform the attributes into an
      #   instance or collection of instances. Accepts either the Class or the
      #   class name as a String. If this option is omitted, the Class will be
      #   inferred from the attribute name. If the singularized attribute name
      #   does not correspond to a Class, the model must define a method to
      #   build an instance from attributes. For example, a +:post+ one-to-one
      #   attribute would call a <tt>build_post(attributes)</tt>
      #   method. Similarly, a +:posts+ one-to-many attribute would also call a
      #   <tt>build_post(attributes)</tt> method.
      # [:array]
      #   Optional boolean to control the type. When `false`,  the relationship
      #   will be one-to-one. When `array: true`, the relationship will be
      #   +:has_many+ . If omitted, the type will be inferred by whether or not
      #   the attribute name is singular or plural.
      #
      # === Examples:
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, class_name: Avatar, reject_if: proc { |attributes| attributes["name"].blank? }
      #   # creates avatar_attributes=
      #   accepts_nested_attributes_for :avatar, class_name: Avatar, reject_if: :all_blank
      #   # creates avatar_attributes= and posts_attributes=
      #   accepts_nested_attributes_for :deer, class_name: Animal, array: true, allow_destroy: true
      def accepts_nested_attributes_for(*nested_attribute_names, **options)
        options[:reject_if] = REJECT_ALL_BLANK_PROC if options[:reject_if] == :all_blank

        nested_attribute_names.each do |attribute_name|
          if instance_methods.include?(:"#{attribute_name}=")
            nested_attributes_options[attribute_name.to_sym] = options.with_defaults(allow_destroy: false)

            type =
              case options[:array]
              when true then :has_many
              when false then :has_one
              else
                attribute_name.to_s.pluralize == attribute_name.to_s ? :has_many : :has_one
              end
            generate_attribute_writer(attribute_name, type)
          else
            raise ArgumentError, "No attribute found for name `#{attribute_name}`. Has it been defined yet?"
          end
        end
      end

      private
        def generate_attribute_writer(attribute_name, type)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            silence_redefinition_of_method :#{attribute_name}_attributes=
            def #{attribute_name}_attributes=(attributes)
              assign_nested_attributes_for_#{type}_attribute(:#{attribute_name}, attributes)
            end
          RUBY
        end
    end

    private
      UNASSIGNABLE_KEYS = %w( _destroy )

      def assign_nested_attributes_for_has_one_attribute(attribute_name, attributes)
        options = nested_attributes_options.fetch(attribute_name)
        attributes = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
        existing_model = public_send(attribute_name)
        assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

        if existing_model
          unless call_reject_if(attribute_name, attributes)
            existing_model.assign_attributes(assignable_attributes)
            if has_destroy_flag?(attributes) && options[:allow_destroy]
              existing_model.try(:mark_for_destruction) || public_send("#{attribute_name}=", nil)
            end
          end
        elsif !reject_new_model?(attribute_name, attributes)
          method = "build_#{attribute_name}"
          if respond_to?(method)
            assign_attributes attribute_name => public_send(method, assignable_attributes)
          elsif can_infer_type_from_attribute_definition?(attribute_name)
            assign_attributes attribute_name => assignable_attributes
          elsif (model_class = infer_class_from_attribute_name(attribute_name.to_s))
            assign_attributes attribute_name => model_class.new(assignable_attributes)
          elsif (class_name = nested_attributes_options.dig(attribute_name, :class_name))
            model_class =
              case class_name
              when String then ActiveSupport::Inflector.constantize(class_name)
              when Class then class_name
              else raise ArgumentError, "Cannot build attribute `#{attribute_name}` with class_name: #{class_name}"
              end

            assign_attributes attribute_name => model_class.new(assignable_attributes)
          else
            raise ArgumentError, "Cannot build attribute `#{attribute_name}`. Specify a class_name: option or define `##{method}`"
          end
        end
      end

      def assign_nested_attributes_for_has_many_attribute(attribute_name, attributes_collection)
        options = nested_attributes_options[attribute_name]

        unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
          raise ArgumentError, "Hash or Array expected for attribute `#{attribute_name}`, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
        end

        attributes_collection = attributes_collection.to_h
        check_record_limit!(options[:limit], attributes_collection)

        if attributes_collection.is_a? Hash
          keys = attributes_collection.keys
          attributes_collection =
            if keys.include?("id") || keys.include?(:id)
              [attributes_collection]
            else
              attributes_collection.values
            end
        end

        if can_infer_type_from_attribute_definition?(attribute_name)
          assignable_attributes = attributes_collection.map do |attributes|
            attributes = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
            attributes.except(*UNASSIGNABLE_KEYS)
          end

          assign_attributes attribute_name => assignable_attributes
        else
          models = attributes_collection.map do |attributes|
            attributes = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
            assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

            unless reject_new_model?(attribute_name, attributes)
              method = "build_#{attribute_name.to_s.singularize}"
              if respond_to?(method)
                public_send(method, assignable_attributes)
              elsif (model_class = infer_class_from_attribute_name(attribute_name.to_s.singularize))
                model_class.new(assignable_attributes)
              elsif (class_name = nested_attributes_options.dig(attribute_name, :class_name))
                model_class =
                  case class_name
                  when String then ActiveSupport::Inflector.constantize(class_name)
                  when Class then class_name
                  else raise ArgumentError, "Cannot build attribute `#{attribute_name}` with class_name: #{class_name}"
                  end

                model_class.new(assignable_attributes)
              else
                raise ArgumentError, "Cannot build attribute `#{attribute_name}`. Specify a class_name: option or define `#{method}`"
              end
            end
          end

          assign_attributes attribute_name => models.tap(&:compact!)
        end
      end

      def can_infer_type_from_attribute_definition?(attribute_name)
        self.class.try(:type_for_attribute, attribute_name).present?
      end

      def infer_class_from_attribute_name(attribute_name)
        attribute_name.classify.safe_constantize
      end

      def reject_new_model?(attribute_name, attributes)
        will_be_destroyed?(attribute_name, attributes) || call_reject_if(attribute_name, attributes)
      end

      def will_be_destroyed?(attribute_name, attributes)
        allow_destroy?(attribute_name) && has_destroy_flag?(attributes)
      end

      def allow_destroy?(attribute_name)
        nested_attributes_options.dig(attribute_name, :allow_destroy)
      end

      # Determines if a hash contains a truthy _destroy key.
      def has_destroy_flag?(hash)
        Type::Boolean.new.cast(hash["_destroy"])
      end

      def call_reject_if(attribute_name, attributes)
        return false if will_be_destroyed?(attribute_name, attributes)

        case callback = nested_attributes_options.dig(attribute_name, :reject_if)
        when Symbol
          method(callback).arity == 0 ? send(callback) : send(callback, attributes)
        when Proc
          callback.call(attributes)
        end
      end

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
            raise TooManyModels, "Maximum #{limit} models are allowed. Got #{attributes_collection.size} models instead."
          end
        end
      end
  end
end
