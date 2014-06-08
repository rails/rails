module ActiveRecord
  # = Active Record Has One Through Association
  module Associations
    class HasOneThroughAssociation < HasOneAssociation #:nodoc:
      include ThroughAssociation

      def replace(record)
        create_through_record(record)
        self.target = record
      end

      private

        def get_records
          if proxy_assoc = get_through_proxy_assoc_if_loaded_and_not_stale
            through_proxy = proxy_assoc.target
            if !through_proxy || ((target_assoc = association_if_loaded_and_not_stale(through_proxy, source_reflection.name)) &&
                                  # if either no record or record is of the wrong polymorphic type
                                  (!(record = target_assoc.target) || !throught_proxy_target_source_type_matches?(record)))
              []
            elsif record
              [record]
            end
          end || super
        end

        def create_through_record(record)
          ensure_not_nested

          through_proxy  = owner.association(through_reflection.name)
          through_record = through_proxy.send(:load_target)

          if through_record && !record
            through_record.destroy
          elsif record
            attributes = construct_join_attributes(record)

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
