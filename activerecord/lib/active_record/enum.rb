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
  #   Conversation.archived
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
  module Enum
    def self.extended(base) # :nodoc:
      base.class_attribute(:defined_enums, instance_writer: false)
      base.defined_enums = {}
    end

    def inherited(base) # :nodoc:
      base.defined_enums = defined_enums.deep_dup
      super
    end

    def enum(definitions)
      klass = self
      definitions.each do |name, values|
        # statuses = { }
        enum_values = ActiveSupport::HashWithIndifferentAccess.new
        name        = name.to_sym

        # def self.statuses statuses end
        detect_enum_conflict!(name, name.to_s.pluralize, true)
        klass.singleton_class.send(:define_method, name.to_s.pluralize) { enum_values }

        _enum_methods_module.module_eval do
          # def status=(value) self[:status] = statuses[value] end
          klass.send(:detect_enum_conflict!, name, "#{name}=")
          define_method("#{name}=") { |value|
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

          # def status() statuses.key self[:status] end
          klass.send(:detect_enum_conflict!, name, name)
          define_method(name) { enum_values.key self[name] }

          # def status_before_type_cast() statuses.key self[:status] end
          klass.send(:detect_enum_conflict!, name, "#{name}_before_type_cast")
          define_method("#{name}_before_type_cast") { enum_values.key self[name] }

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            enum_values[value] = i

            # def active?() status == 0 end
            klass.send(:detect_enum_conflict!, name, "#{value}?")
            define_method("#{value}?") { self[name] == i }

            # def active!() update! status: :active end
            klass.send(:detect_enum_conflict!, name, "#{value}!")
            define_method("#{value}!") { update! name => value }

            # scope :active, -> { where status: 0 }
            klass.send(:detect_enum_conflict!, name, value, true)
            klass.scope value, -> { klass.where name => i }
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
              def save_changed_attribute(attr_name, old)
                if (mapping = self.class.defined_enums[attr_name.to_s])
                  value = _read_attribute(attr_name)
                  if attribute_changed?(attr_name)
                    if mapping[old] == value
                      clear_attribute_changes([attr_name])
                    end
                  else
                    if old != value
                      set_attribute_was(attr_name, mapping.key(old))
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
