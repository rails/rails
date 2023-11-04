# frozen_string_literal: true

require "active_support/core_ext/hash/slice"
require "active_support/core_ext/object/deep_dup"

module ActiveRecord
  # Declare an enum attribute where the values map to integers in the database,
  # but can be queried by name. Example:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ]
  #   end
  #
  #   # conversation.update! status: 0
  #   conversation.active!
  #   conversation.active? # => true
  #   conversation.status  # => "active"
  #
  #   # conversation.update! status: 1
  #   conversation.archived!
  #   conversation.archived? # => true
  #   conversation.status    # => "archived"
  #
  #   # conversation.status = 1
  #   conversation.status = "archived"
  #
  #   conversation.status = nil
  #   conversation.status.nil? # => true
  #   conversation.status      # => nil
  #
  # Scopes based on the allowed values of the enum field will be provided
  # as well. With the above example:
  #
  #   Conversation.active
  #   Conversation.not_active
  #   Conversation.archived
  #   Conversation.not_archived
  #
  # Of course, you can also query them directly if the scopes don't fit your
  # needs:
  #
  #   Conversation.where(status: [:active, :archived])
  #   Conversation.where.not(status: :active)
  #
  # Defining scopes can be disabled by setting +:scopes+ to +false+.
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], scopes: false
  #   end
  #
  # You can set the default enum value by setting +:default+, like:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], default: :active
  #   end
  #
  #   conversation = Conversation.new
  #   conversation.status # => "active"
  #
  # It's possible to explicitly map the relation between attribute and
  # database integer with a hash:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, active: 0, archived: 1
  #   end
  #
  # Finally it's also possible to use a string column to persist the enumerated value.
  # Note that this will likely lead to slower database queries:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, active: "active", archived: "archived"
  #   end
  #
  # Note that when an array is used, the implicit mapping from the values to database
  # integers is derived from the order the values appear in the array. In the example,
  # <tt>:active</tt> is mapped to +0+ as it's the first element, and <tt>:archived</tt>
  # is mapped to +1+. In general, the +i+-th element is mapped to <tt>i-1</tt> in the
  # database.
  #
  # Therefore, once a value is added to the enum array, its position in the array must
  # be maintained, and new values should only be added to the end of the array. To
  # remove unused values, the explicit hash syntax should be used.
  #
  # In rare circumstances you might need to access the mapping directly.
  # The mappings are exposed through a class method with the pluralized attribute
  # name, which return the mapping in a ActiveSupport::HashWithIndifferentAccess :
  #
  #   Conversation.statuses[:active]    # => 0
  #   Conversation.statuses["archived"] # => 1
  #
  # Use that class method when you need to know the ordinal value of an enum.
  # For example, you can use that when manually building SQL strings:
  #
  #   Conversation.where("status <> ?", Conversation.statuses[:archived])
  #
  # You can use the +:prefix+ or +:suffix+ options when you need to define
  # multiple enums with same values. If the passed value is +true+, the methods
  # are prefixed/suffixed with the name of the enum. It is also possible to
  # supply a custom value:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], suffix: true
  #     enum :comments_status, [ :active, :inactive ], prefix: :comments
  #   end
  #
  # With the above example, the bang and predicate methods along with the
  # associated scopes are now prefixed and/or suffixed accordingly:
  #
  #   conversation.active_status!
  #   conversation.archived_status? # => false
  #
  #   conversation.comments_inactive!
  #   conversation.comments_active? # => false
  #
  # If you want to disable the auto-generated methods on the model, you can do
  # so by setting the +:instance_methods+ option to false:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], instance_methods: false
  #   end
  #
  # If you want the enum value to be validated before saving, use the option +:validate+:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], validate: true
  #   end
  #
  #   conversation = Conversation.new
  #
  #   conversation.status = :unknown
  #   conversation.valid? # => false
  #
  #   conversation.status = nil
  #   conversation.valid? # => false
  #
  #   conversation.status = :active
  #   conversation.valid? # => true
  #
  # It is also possible to pass additional validation options:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ], validate: { allow_nil: true }
  #   end
  #
  #   conversation = Conversation.new
  #
  #   conversation.status = :unknown
  #   conversation.valid? # => false
  #
  #   conversation.status = nil
  #   conversation.valid? # => true
  #
  #   conversation.status = :active
  #   conversation.valid? # => true
  #
  # Otherwise +ArgumentError+ will raise:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, [ :active, :archived ]
  #   end
  #
  #   conversation = Conversation.new
  #
  #   conversation.status = :unknown # 'unknown' is not a valid status (ArgumentError)
  module Enum
    extend ActiveSupport::Concern
    include ActiveModel::Enum

    module ClassMethods
      private
        def _enum(name, values, prefix: nil, suffix: nil, scopes: true, instance_methods: true, validate: false, **options)
          super
        end

        class EnumMethods < Module # :nodoc:
          def initialize(klass)
            @klass = klass
          end

          private
            attr_reader :klass

            def define_enum_methods(name, value_method_name, value, scopes, instance_methods)
              if instance_methods
                # def active?() status_for_database == 0 end
                klass.send(:detect_enum_conflict!, name, "#{value_method_name}?")
                define_method("#{value_method_name}?") { public_send(:"#{name}_for_database") == value }

                # def active!() update!(status: 0) end
                klass.send(:detect_enum_conflict!, name, "#{value_method_name}!")
                define_method("#{value_method_name}!") { update!(name => value) }
              end

              if scopes
                # scope :active, -> { where(status: 0) }
                klass.send(:detect_enum_conflict!, name, value_method_name, true)
                klass.scope value_method_name, -> { where(name => value) }

                # scope :not_active, -> { where.not(status: 0) }
                klass.send(:detect_enum_conflict!, name, "not_#{value_method_name}", true)
                klass.scope "not_#{value_method_name}", -> { where.not(name => value) }
              end
            end
        end
        private_constant :EnumMethods

        def _enum_methods_module
          @_enum_methods_module ||= begin
            mod = EnumMethods.new(self)
            include mod
            mod
          end
        end

        ENUM_CONFLICT_MESSAGE = \
          "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
          "this will generate a %{type} method \"%{method}\", which is already defined " \
          "by %{source}."
        private_constant :ENUM_CONFLICT_MESSAGE

        def detect_enum_conflict!(enum_name, method_name, klass_method = false)
          if klass_method && dangerous_class_method?(method_name)
            raise_conflict_error(enum_name, method_name, type: "class")
          elsif klass_method && method_defined_within?(method_name, Relation)
            raise_conflict_error(enum_name, method_name, type: "class", source: Relation.name)
          elsif klass_method && method_name.to_sym == :id
            raise_conflict_error(enum_name, method_name)
          elsif !klass_method && dangerous_attribute_method?(method_name)
            raise_conflict_error(enum_name, method_name)
          elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
            raise_conflict_error(enum_name, method_name, source: "another enum")
          end
        end

        def raise_conflict_error(enum_name, method_name, type: "instance", source: "Active Record")
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: name,
            type: type,
            method: method_name,
            source: source
          }
        end

        def detect_negative_enum_conditions!(method_names)
          return unless logger

          method_names.select { |m| m.start_with?("not_") }.each do |potential_not|
            inverted_form = potential_not.sub("not_", "")
            if method_names.include?(inverted_form)
              logger.warn "Enum element '#{potential_not}' in #{self.name} uses the prefix 'not_'." \
                " This has caused a conflict with auto generated negative scopes." \
                " Avoid using enum elements starting with 'not' where the positive form is also an element."
            end
          end
        end
    end
  end
end
