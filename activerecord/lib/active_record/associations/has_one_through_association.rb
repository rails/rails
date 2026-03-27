# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Through Association
    class HasOneThroughAssociation < HasOneAssociation # :nodoc:
      include ThroughAssociation

      # Override reader to walk the loaded through chain when possible,
      # avoiding an unnecessary database query for preloaded associations.
      def reader
        if !loaded? && !stale_target? && through_chain_loaded?
          self.target = resolve_target_from_through_chain
        end

        super
      end

      private
        def through_chain_loaded?
          through_assoc = through_association
          return false unless through_assoc.loaded?

          through_target = through_assoc.target
          return true unless through_target

          through_target.association(source_reflection.name).loaded?
        end

        def resolve_target_from_through_chain
          through_target = through_association.target
          return nil unless through_target
          through_target.association(source_reflection.name).target
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
