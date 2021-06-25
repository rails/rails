# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Through Association
    class HasOneThroughAssociation < HasOneAssociation #:nodoc:
      include ThroughAssociation

      def reader
        if load_target_from_memory?
          self.target = find_target_from_memory
        else
          super
        end
      end

      private
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

        def load_target_from_memory?
          !load_target? && !loaded? && owner.new_record?
        end

        # Recursively reads the through_associations and collects their values.
        def find_target_from_memory
          through_record = owner.association(reflection.through_reflection.name).reader
          through_record&.association(source_reflection.name)&.reader
        end
    end
  end
end
