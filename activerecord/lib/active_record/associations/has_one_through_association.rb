# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Through Association
    class HasOneThroughAssociation < HasOneAssociation # :nodoc:
      include ThroughAssociation

      private
        def find_target(async: false)
          # If the through association is already loaded and its target also has
          # the source association loaded, traverse the loaded chain instead of
          # firing a database query. This prevents N+1 queries when the entire
          # object graph has been eager-loaded via includes().
          if through_association.loaded?
            through_target = through_association.target
            if through_target
              source_assoc = through_target.association(source_reflection.name)
              if source_assoc.loaded?
                return source_assoc.target
              end
            else
              return nil
            end
          end

          super
        end

        def replace(record, save = true)
          create_through_record(record, save)
          self.target = record
        end

        def create_through_record(record, save)
          ensure_not_nested

          through_proxy  = through_association
          through_record = through_proxy.load_target

          if through_record && !record
            through_record.destroy
          elsif record
            attributes = construct_join_attributes(record)

            if through_record && through_record.destroyed?
              through_record = through_proxy.tap(&:reload).target
            end

            if through_record
              if through_record.new_record?
                through_record.assign_attributes(attributes)
              else
                through_record.update(attributes)
              end
            elsif owner.new_record? || !save
              through_proxy.build(attributes)
            else
              through_proxy.create(attributes)
            end
          end
        end
    end
  end
end
