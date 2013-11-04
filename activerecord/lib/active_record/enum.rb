module ActiveRecord
  # Declare an enum attribute where the values map to integers in the database, but can be queried by name. Example:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: [ :active, :archived ]
  #   end
  #
  #   Conversation::STATUS # => { active: 0, archived: 1 }
  #
  #   # conversation.update! status: 0
  #   conversation.active!
  #   conversation.active? # => true
  #   conversation.status  # => :active
  #
  #   # conversation.update! status: 1
  #   conversation.archived!
  #   conversation.archived? # => true
  #   conversation.status    # => :archived
  #
  #   # conversation.update! status: 1
  #   conversation.status = :archived
  #
  # You can set the default value from the database declaration, like:
  #
  #   create_table :conversations do |t|
  #     t.column :status, :integer, default: 0
  #   end
  #
  # Good practice is to let the first declared status be the default.
  #
  # Finally, it's also possible to explicitly map the relation between attribute and database integer:
  #
  #   class Conversation < ActiveRecord::Base
  #     enum status: { active: 0, archived: 1 }
  #   end
  module Enum
    def enum(definitions)
      definitions.each do |name, values|
        # DIRECTION = { }
        const = const_set name.to_s.upcase, {}

        # def direction=(value) self[:direction] = DIRECTION[value] end
        define_method "#{name}=" do |value|
          self[:"#{name}"] = const[value]
        end

        # def direction() DIRECTION.key self[:direction] end
        define_method name do
          const.key self[:"#{name}"]
        end

        pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
        pairs.each do |value, i|
          # DIRECTION[:incoming] = 0
          const[value] = i

          # scope :incoming, -> { where direction: 0 }
          scope value, -> { where name => i }

          # def incoming?() direction == 0 end
          define_method "#{value}?" do
            self[:"#{name}"] == i
          end

          # def incoming! update! direction: :incoming end
          define_method "#{value}!" do
            update! :"#{name}" => :"#{value}"
          end
        end
      end
    end
  end
end
