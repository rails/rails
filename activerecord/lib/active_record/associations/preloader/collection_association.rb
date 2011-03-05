module ActiveRecord
  module Associations
    class Preloader
      class CollectionAssociation < Association #:nodoc:

        private

        def build_scope
          super.order(preload_options[:order] || options[:order])
        end

        def preload
          associated_records_by_owner.each do |owner, records|
            association = owner.association(reflection.name)
            association.loaded!
            association.target.concat(records)
            records.each { |record| association.set_inverse_instance(record) }
          end
        end

      end
    end
  end
end
