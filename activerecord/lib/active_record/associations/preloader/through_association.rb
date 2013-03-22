module ActiveRecord
  module Associations
    class Preloader
      module ThroughAssociation #:nodoc:

        def through_reflection
          reflection.through_reflection
        end

        def source_reflection
          reflection.source_reflection
        end

        def associated_records_by_owner
          through_records = through_records_by_owner

          ActiveRecord::Associations::Preloader.new(
            through_records.values.flatten,
            source_reflection.name, options
          ).run

          through_records.each do |owner, records|
            records.map! { |r| r.send(source_reflection.name) }.flatten!
            records.compact!
          end
        end

        private

        def through_records_by_owner
          ActiveRecord::Associations::Preloader.new(
            owners, through_reflection.name,
            through_options
          ).run

          Hash[owners.map do |owner|
            through_records = Array.wrap(owner.send(through_reflection.name))

            # Dont cache the association - we would only be caching a subset
            if (preload_options != through_options) ||
               (reflection.options[:source_type] && through_reflection.collection?)
              owner.association(through_reflection.name).reset
            end

            [owner, through_records]
          end]
        end

        def through_options
          through_options = {}

          if options[:source_type]
            through_options[:conditions] = { reflection.foreign_type => options[:source_type] }
          else
            if options[:conditions]
              through_options[:include]    = options[:include] || options[:source]
              through_options[:conditions] = options[:conditions]
            end
            through_options[:order] = options[:order] if options.has_key?(:order)
          end

          through_options
        end
      end
    end
  end
end
