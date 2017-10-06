# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Through Association
    class HasOneThroughAssociation < HasOneAssociation #:nodoc:
      include ThroughAssociation

      def replace(record)
        create_through_record(record)
        self.target = record
      end

      private

        def create_through_record(record)
          ensure_not_nested

          through_proxy  = owner.association(through_reflection.name)
          through_record = through_proxy.load_target

          if through_record && !record
            through_record.destroy
          elsif record
            attributes = construct_join_attributes(record)

            if through_record && through_record.destroyed?
              through_record = through_proxy.tap(&:reload).target
            end

            if through_record
              through_record.update(attributes)
            elsif owner.new_record?
              through_proxy.build(attributes)
            else
              through_proxy.create(attributes)
            end
          end
        end
    end
  end
end
