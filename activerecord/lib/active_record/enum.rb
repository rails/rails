module ActiveRecord
  # Declare an enum attribute where the values map to integers in the database, but can be queried by name. Example:
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
  # The mappings are exposed through a constant with the attributes name:
  #
  #   Conversation::STATUS # => { "active" => 0, "archived" => 1 }
  #
  # Use that constant when you need to know the ordinal value of an enum:
  #
  #   Conversation.where("status <> ?", Conversation::STATUS[:archived])
  module Enum
    def enum(definitions)
      klass = self
      definitions.each do |name, values|
        # STATUS = { }
        enum_values = _enum_methods_module.const_set name.to_s.upcase, ActiveSupport::HashWithIndifferentAccess.new
        name        = name.to_sym

        _enum_methods_module.module_eval do
          # def status=(value) self[:status] = STATUS[value] end
          define_method("#{name}=") { |value|
            unless enum_values.has_key?(value)
              raise ArgumentError, "'#{value}' is not a valid #{name}"
            end
            self[name] = enum_values[value]
          }

          # def status() STATUS.key(self[:status]).try(:to_sym) end
          define_method(name) { enum_values.key(self[name]).try(:to_sym) }

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            enum_values[value] = i

            # scope :active, -> { where status: 0 }
            klass.scope value, -> { klass.where name => i }

            # def active?() status == 0 end
            define_method("#{value}?") { self[name] == i }

            # def active! update! status: :active end
            define_method("#{value}!") { update! name => value }
          end
        end
      end
    end

    private
      def _enum_methods_module
        @_enum_methods_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end
  end
end
