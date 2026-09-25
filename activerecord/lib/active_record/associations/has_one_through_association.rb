# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Through Association
    class HasOneThroughAssociation < HasOneAssociation # :nodoc:
      include ThroughAssociation

      def load_target
        if (!loaded? || @inferred_target) && (records = target_from_through_records)
          @target = records.first
          @inferred_target = true
          loaded!
          target
        else
          super
        end
      end

      # An inferred target follows the through records while the owner is new,
      # and is read from the database once the owner is saved.
      def stale_target?
        (loaded? && @inferred_target) || super
      end

      def reset
        super
        @inferred_target = false
      end

      def target=(record)
        @inferred_target = false
        super
      end

      def inferred_from_through_records?(record) # :nodoc:
        @inferred_target && record.equal?(target)
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
    end
  end
end
