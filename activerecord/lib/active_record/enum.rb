require 'active_support/core_ext/object/deep_dup'

module ActiveRecord
  # Declare an enum attribute where the values map to integers in the database,
  # but can be queried by name. Example:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: [ :active, :archived ]
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
  #   # conversation.update! status: 1
  #   conversation.status = "archived"
  #
  #   # conversation.update! status: nil
  #   conversation.status = nil
  #   conversation.status.nil? # => true
  #   conversation.status      # => nil
  #
  # Scopes based on the allowed values of the enum field will be provided
  # as well. With the above example, it will create an +active+ and +archived+
  # scope.
  #
  # You can set the default value from the database declaration, like:
  #
  #   create_table :conversations do |t|
  #     t.column :status, :integer, default: 0
  #   end
  #
  # Good practice is to let the first declared status be the default.
  #
  # Finally, it's also possible to explicitly map the relation between attribute and
  # database integer with a +Hash+:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: { active: 0, archived: 1 }
  #   end
  #
  # Note that when an +Array+ is used, the implicit mapping from the values to database
  # integers is derived from the order the values appear in the array. In the example,
  # <tt>:active</tt> is mapped to +0+ as it's the first element, and <tt>:archived</tt>
  # is mapped to +1+. In general, the +i+-th element is mapped to <tt>i-1</tt> in the
  # database.
  #
  # Therefore, once a value is added to the enum array, its position in the array must
  # be maintained, and new values should only be added to the end of the array. To
  # remove unused values, the explicit +Hash+ syntax should be used.
  #
  # In rare circumstances you might need to access the mapping directly.
  # The mappings are exposed through a class method with the pluralized attribute
  # name:
  #
  #   Conversation.statuses # => { "active" => 0, "archived" => 1 }
  #
  # Use that class method when you need to know the ordinal value of an enum:
  #
  #   Conversation.where("status <> ?", Conversation.statuses[:archived])
  #
  # Where conditions on an enum attribute must use the ordinal value of an enum.
  #
  # === Options
  #
  # You can pass options to enum as a block:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: { active: 0, archived: 1 } do |config|
  #       config.skip   = [:writer, :reader, :accessor, :question_marks,
  #                        :updates, :scopes]
  #       config.prefix = true
  #     end
  #   end
  #
  # +skip+ will avoid creating methods you don't want, if you pass:
  #
  # * <tt>writer</tt>, this will avoid overriding +conversation.status=+
  # * <tt>reader</tt>, this will avoid overriding +conversation.status+
  # * <tt>accessor</tt>, this will avoid overriding +conversation.status=+ and +conversation.status+
  # * <tt>question_marks</tt>, this will avoid defining +conversation.active?+ and +conversation.archived?+
  # * <tt>updates</tt>, this will avoid defining +conversation.active!+ and +conversation.archived!+
  # * <tt>scopes</tt>, this will avoid defining +Conversation.active+ and +Conversation.archived+
  #
  # +prefix+ will add the name of the field as a prefix to the new defined methods:
  #
  #   conversation.status_active!
  #   conversation.status_active?
  #   Conversation.status_active
  module Enum
    class EnumOptions < Struct.new(:skip, :prefix)
      VALID_SKIP_ATTRIBUTES = [:writer, :reader, :accessor, :question_marks,
        :updates, :scopes]
      VALID_PREFIX_ATTRIBUTES = [true, false, nil]

      def valid_options
        members
      end

      def valid_option_attributes?(option, attributes)
        case option
        when :skip
          valid_skip_attributes?
        when :prefix
          valid_prefix_attribute?
        end
      end

      def valid_options?
        valid_options.each do |option|
          attributes = self.send(option)
          valid_option_attributes?(option, attributes)
        end
      end

      def skip_method_definitions?(method_type)
        skip_attributes = to_array(skip)
        skip_attributes && skip_attributes.include?(method_type)
      end

      def get_method_name(name, field)
        prefix ? "#{field}_#{name}" : name
      end

      private

        def valid_skip_attributes? # :nodoc:
          attributes = to_array(skip)

          attributes.each do |attribute|
            valid_attribute = VALID_SKIP_ATTRIBUTES.include?(attribute)

            unless valid_attribute
              raise ArgumentError, "':#{attribute}' is not a valid value for skip of enum."
            end
          end
        end

        def valid_prefix_attribute? # :nodoc:
          valid_attribute = VALID_PREFIX_ATTRIBUTES.include?(prefix)

          unless valid_attribute
            raise ArgumentError, "'#{prefix}' is not a valid value for prefix of enum."
          end
        end

        def to_array(attribute) # :nodoc:
          return attribute if attribute.is_a?(Array)
          [attribute].flatten.compact
        end
    end

    def self.extended(base)
      base.class_attribute(:defined_enums)
      base.defined_enums = {}
    end

    def inherited(base)
      base.defined_enums = defined_enums.deep_dup
      super
    end

    def enum(definitions)
      klass = self
      options = EnumOptions.new

      yield(options) if block_given?
      options.valid_options?

      definitions.each do |name, values|
        # statuses = { }
        enum_values = ActiveSupport::HashWithIndifferentAccess.new
        name        = name.to_sym

        # def self.statuses statuses end
        detect_enum_conflict!(name, name.to_s.pluralize, true)
        klass.singleton_class.send(:define_method, name.to_s.pluralize) { enum_values }

        _enum_methods_module.module_eval do
          unless options.skip_method_definitions?(:writer) ||
            options.skip_method_definitions?(:accessor)
            # def status=(value) self[:status] = statuses[value] end
            method_name = "#{name}="
            klass.send(:detect_enum_conflict!, name, method_name)
            define_method(method_name) { |value|
              if enum_values.has_key?(value) || value.blank?
                self[name] = enum_values[value]
              elsif enum_values.has_value?(value)
                # Assigning a value directly is not a end-user feature, hence it's not documented.
                # This is used internally to make building objects from the generated scopes work
                # as expected, i.e. +Conversation.archived.build.archived?+ should be true.
                self[name] = value
              else
                raise ArgumentError, "'#{value}' is not a valid #{name}"
              end
            }
          end

          unless options.skip_method_definitions?(:reader) ||
            options.skip_method_definitions?(:accessor)
            # def status() statuses.key self[:status] end
            klass.send(:detect_enum_conflict!, name, name)
            define_method(name) { enum_values.key self[name] }

            # def status_before_type_cast() statuses.key self[:status] end
            method_name = "#{name}_before_type_cast"
            klass.send(:detect_enum_conflict!, name, method_name)
            define_method(method_name) { enum_values.key self[name] }
          end

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            method_name = options.get_method_name("#{value}", name)
            enum_values[method_name] = i

            unless options.skip_method_definitions?(:question_marks)
              # def active?() status == 0 end
              method_name = options.get_method_name("#{value}?", name)
              klass.send(:detect_enum_conflict!, name, method_name)
              define_method(method_name) { self[name] == i }
            end

            unless options.skip_method_definitions?(:updates)
              # def active!() update! status: :active end
              method_name = options.get_method_name("#{value}!", name)
              klass.send(:detect_enum_conflict!, name, method_name)
              define_method(method_name) { update! name => value }
            end

            unless options.skip_method_definitions?(:scopes)
              # scope :active, -> { where status: 0 }
              method_name = options.get_method_name(value, name)
              klass.send(:detect_enum_conflict!, name, method_name, true)
              klass.scope method_name, -> { klass.where name => i }
            end
          end
        end
        defined_enums[name.to_s] = enum_values
      end
    end

    private
      def _enum_methods_module
        @_enum_methods_module ||= begin
          mod = Module.new do
            private
              def save_changed_attribute(attr_name, value)
                if (mapping = self.class.defined_enums[attr_name.to_s])
                  if attribute_changed?(attr_name)
                    old = changed_attributes[attr_name]

                    if mapping[old] == value
                      changed_attributes.delete(attr_name)
                    end
                  else
                    old = clone_attribute_value(:read_attribute, attr_name)

                    if old != value
                      changed_attributes[attr_name] = mapping.key old
                    end
                  end
                else
                  super
                end
              end
          end
          include mod
          mod
        end
      end

      ENUM_CONFLICT_MESSAGE = \
        "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
        "this will generate a %{type} method \"%{method}\", which is already defined " \
        "by %{source}."

      def detect_enum_conflict!(enum_name, method_name, klass_method = false)
        if klass_method && dangerous_class_method?(method_name)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'class',
            method: method_name,
            source: 'Active Record'
          }
        elsif !klass_method && dangerous_attribute_method?(method_name)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'instance',
            method: method_name,
            source: 'Active Record'
          }
        elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'instance',
            method: method_name,
            source: 'another enum'
          }
        end
      end
  end
end
