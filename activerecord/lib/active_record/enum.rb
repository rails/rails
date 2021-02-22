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
  # Finally, it's also possible to explicitly map the relation between attribute and
  # database integer with a hash:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum :status, active: 0, archived: 1
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
  # name, which return the mapping in a +HashWithIndifferentAccess+:
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
  module Enum
    def self.extended(base) # :nodoc:
      base.class_attribute(:defined_enums, instance_writer: false, default: {})
    end

    def inherited(base) # :nodoc:
      base.defined_enums = defined_enums.deep_dup
      super
    end

    class EnumType < Type::Value # :nodoc:
      delegate :type, to: :subtype

      def initialize(name, mapping, subtype)
        @name = name
        @mapping = mapping
        @subtype = subtype
      end

      def cast(value)
        if mapping.has_key?(value)
          value.to_s
        elsif mapping.has_value?(value)
          mapping.key(value)
        elsif value.blank?
          nil
        else
          assert_valid_value(value)
        end
      end

      def deserialize(value)
        mapping.key(subtype.deserialize(value))
      end

      def serialize(value)
        mapping.fetch(value, value)
      end

      def assert_valid_value(value)
        unless value.blank? || mapping.has_key?(value) || mapping.has_value?(value)
          raise ArgumentError, "'#{value}' is not a valid #{name}"
        end
      end

      attr_reader :subtype

      private
        attr_reader :name, :mapping
    end

    def enum(name = nil, values = nil, **options)
      if name
        values, options = options, {} unless values
        return _enum(name, values, **options)
      end

      definitions = options.slice!(:_prefix, :_suffix, :_scopes, :_default)
      options.transform_keys! { |key| :"#{key[1..-1]}" }

      definitions.each { |name, values| _enum(name, values, **options) }
    end

    private
      def _enum(name, values, prefix: nil, suffix: nil, scopes: true, **options)
        assert_valid_enum_definition_values(values)
        # statuses = { }
        enum_values = ActiveSupport::HashWithIndifferentAccess.new
        name = name.to_s

        # def self.statuses() statuses end
        detect_enum_conflict!(name, name.pluralize, true)
        singleton_class.define_method(name.pluralize) { enum_values }
        defined_enums[name] = enum_values

        detect_enum_conflict!(name, name)
        detect_enum_conflict!(name, "#{name}=")

        attribute(name, **options) do |subtype|
          subtype = subtype.subtype if EnumType === subtype
          EnumType.new(name, enum_values, subtype)
        end

        value_method_names = []
        _enum_methods_module.module_eval do
          prefix = if prefix
            prefix == true ? "#{name}_" : "#{prefix}_"
          end

          suffix = if suffix
            suffix == true ? "_#{name}" : "_#{suffix}"
          end

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |label, value|
            enum_values[label] = value
            label = label.to_s

            value_method_name = "#{prefix}#{label}#{suffix}"
            value_method_names << value_method_name
            define_enum_methods(name, value_method_name, value, scopes)

            method_friendly_label = label.gsub(/[\W&&[:ascii:]]+/, "_")
            value_method_alias = "#{prefix}#{method_friendly_label}#{suffix}"

            if value_method_alias != value_method_name && !value_method_names.include?(value_method_alias)
              value_method_names << value_method_alias
              define_enum_methods(name, value_method_alias, value, scopes)
            end
          end
        end
        detect_negative_enum_conditions!(value_method_names) if scopes
        enum_values.freeze
      end

      class EnumMethods < Module # :nodoc:
        def initialize(klass)
          @klass = klass
        end

        private
          attr_reader :klass

          def define_enum_methods(name, value_method_name, value, scopes)
            # def active?() status_for_database == 0 end
            klass.send(:detect_enum_conflict!, name, "#{value_method_name}?")
            define_method("#{value_method_name}?") { public_send(:"#{name}_for_database") == value }

            # def active!() update!(status: 0) end
            klass.send(:detect_enum_conflict!, name, "#{value_method_name}!")
            define_method("#{value_method_name}!") { update!(name => value) }

            # scope :active, -> { where(status: 0) }
            # scope :not_active, -> { where.not(status: 0) }
            if scopes
              klass.send(:detect_enum_conflict!, name, value_method_name, true)
              klass.scope value_method_name, -> { where(name => value) }

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

      def assert_valid_enum_definition_values(values)
        unless values.is_a?(Hash) || values.all?(Symbol) || values.all?(String)
          error_message = <<~MSG
            Enum values #{values} must be either a hash, an array of symbols, or an array of strings.
          MSG
          raise ArgumentError, error_message
        end

        if values.is_a?(Hash) && values.keys.any?(&:blank?) || values.is_a?(Array) && values.any?(&:blank?)
          raise ArgumentError, "Enum label name must not be blank."
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
