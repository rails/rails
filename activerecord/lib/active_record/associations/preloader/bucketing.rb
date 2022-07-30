# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      module Bucketing # :nodoc:
        private
          def build_bucket(source_records, association_name)
            source_records.map { |record| WeakRef.new(record.association(association_name)) }
          end

          def link_records_to_bucket(target_records, bucket)
            target_records.each { |record| record.preloading_bucket = bucket }
          end

          def gather_records_from_linked_buckets(source_records)
            source_records.map(&:preloading_bucket).uniq.flat_map do |bucket|
              bucket&.flat_map do |association|
                association.target if association.weakref_alive?
              end
            end.compact.concat(source_records)
          end
      end
    end
  end
end
