# frozen_string_literal: true

require "active_support"
require "active_support/cache"

module ActiveRecord
  module Marshalling
    @format_version = 6.1

    class << self
      attr_reader :format_version

      def format_version=(version)
        case version
        when 6.1
          Methods.remove_method(:_dump) if Methods.method_defined?(:_dump)
        when 7.1
          Methods.alias_method(:_dump, :_dump_7_1)
        else
          raise ArgumentError, "Unknown marshalling format: #{version.inspect}"
        end
        @format_version = version
      end
    end

    module Methods
      def _dump_7_1(_level)
        Marshal.dump(Coder.dump(self))
      end
    end

    module ClassMethods
      def _load(payload)
        Coder.load(Marshal.load(payload))
      end
    end

    module Coder # :nodoc:
      class << self
        def dump(record)
          instances = InstanceTracker.new
          serialized_associations = serialize_associations(record, instances)
          serialized_records = instances.map { |r| serialize_record(r) }
          [serialized_associations, *serialized_records]
        end

        def load(payload)
          instances = InstanceTracker.new
          serialized_associations, *serialized_records = payload
          serialized_records.each { |attrs| instances.push(deserialize_record(*attrs)) }
          deserialize_associations(serialized_associations, instances)
        end

        private
          # Records without associations, or which have already been visited before,
          # are serialized by their id alone.
          #
          # Records with associations are serialized as a two-element array including
          # their id and the record's association cache.
          #
          def serialize_associations(record, instances)
            return unless record

            if (id = instances.lookup(record))
              payload = id
            else
              payload = instances.push(record)

              cached_associations = record.class.reflect_on_all_associations.select do |reflection|
                record.association_cached?(reflection.name)
              end

              unless cached_associations.empty?
                serialized_associations = cached_associations.map do |reflection|
                  association = record.association(reflection.name)

                  serialized_target = if reflection.collection?
                    association.target.map { |target_record| serialize_associations(target_record, instances) }
                  else
                    serialize_associations(association.target, instances)
                  end

                  [reflection.name, serialized_target]
                end

                payload = [payload, serialized_associations]
              end
            end

            payload
          end

          def deserialize_associations(payload, instances)
            return unless payload

            id, associations = payload
            record = instances.fetch(id)

            associations&.each do |name, serialized_target|
              begin
                association = record.association(name)
              rescue ActiveRecord::AssociationNotFoundError
                raise AssociationMissingError, "undefined association: #{name}"
              end

              target = if association.reflection.collection?
                serialized_target.map! { |serialized_record| deserialize_associations(serialized_record, instances) }
              else
                deserialize_associations(serialized_target, instances)
              end

              association.target = target
            end

            record
          end

          def serialize_record(record)
            arguments = [record.class.name, attributes_for_database(record)]
            arguments << true if record.new_record?
            arguments
          end

          def attributes_for_database(record)
            attributes = record.attributes_for_database
            # FIXME: we shouldn't have to do this. We may need an `attributes_for_serialization` that only return basic
            # Ruby core types.
            attributes.transform_values! { |attr| attr.is_a?(::ActiveModel::Type::Binary::Data) ? attr.to_s : attr }
            attributes
          end

          def deserialize_record(class_name, attributes_from_database, new_record = false)
            begin
              klass = Object.const_get(class_name)
            rescue NameError
              raise ClassMissingError, "undefined class: #{class_name}"
            end

            attributes = klass.attributes_builder.build_from_database(attributes_from_database)
            klass.allocate.init_with_attributes(attributes, new_record)
          end
      end

      class Error < ActiveRecordError
        include ActiveSupport::Cache::DeserializationError
      end

      class ClassMissingError < Error
      end

      class AssociationMissingError < Error
      end
    end

    class InstanceTracker # :nodoc:
      def initialize
        @instances = []
        @ids = {}.compare_by_identity
      end

      def map(&block)
        @instances.map(&block)
      end

      def fetch(...)
        @instances.fetch(...)
      end

      def push(instance)
        id = @ids[instance] = @instances.size
        @instances << instance
        id
      end

      def lookup(instance)
        @ids[instance]
      end
    end
  end
end
