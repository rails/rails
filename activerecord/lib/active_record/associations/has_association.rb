module ActiveRecord
  module Associations
    # Included in all has_* associations (i.e. everything except belongs_to)
    module HasAssociation #:nodoc:
      protected
        # Sets the owner attributes on the given record
        def set_owner_attributes(record)
          if @owner.persisted?
            construct_owner_attributes.each { |key, value| record[key] = value }
          end
        end

        # Returns a hash linking the owner to the association represented by the reflection
        def construct_owner_attributes(reflection = @reflection)
          attributes = {}
          if reflection.macro == :belongs_to
            attributes[reflection.association_primary_key] = @owner.send(reflection.foreign_key)
          else
            attributes[reflection.foreign_key] = @owner.send(reflection.active_record_primary_key)

            if reflection.options[:as]
              attributes["#{reflection.options[:as]}_type"] = @owner.class.base_class.name
            end
          end
          attributes
        end

        # Builds an array of arel nodes from the owner attributes hash
        def construct_owner_conditions(table = aliased_table, reflection = @reflection)
          construct_owner_attributes(reflection).map do |attr, value|
            table[attr].eq(value)
          end
        end

        def construct_conditions
          conditions = construct_owner_conditions
          conditions << Arel.sql(sql_conditions) if sql_conditions
          aliased_table.create_and(conditions)
        end
    end
  end
end
