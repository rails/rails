# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Automatically expand encrypted arguments to support querying both encrypted and unencrypted data
    #
    # Active Record \Encryption supports querying the db using deterministic attributes. For example:
    #
    #   Contact.find_by(email_address: "jorge@hey.com")
    #
    # The value "jorge@hey.com" will get encrypted automatically to perform the query. But there is
    # a problem while the data is being encrypted. This won't work. During that time, you need these
    # queries to be:
    #
    #   Contact.find_by(email_address: [ "jorge@hey.com", "<encrypted jorge@hey.com>" ])
    #
    # This patches ActiveRecord to support this automatically. It addresses both:
    #
    # * ActiveRecord::Base - Used in <tt>Contact.find_by_email_address(...)</tt>
    # * ActiveRecord::Relation - Used in <tt>Contact.internal.find_by_email_address(...)</tt>
    #
    # This module is included if `config.active_record.encryption.extend_queries` is `true`.
    module ExtendedDeterministicQueries
      def self.install_support
        # ActiveRecord::Base relies on ActiveRecord::Relation (ActiveRecord::QueryMethods) but it does
        # some prepared statements caching. That's why we need to intercept +ActiveRecord::Base+ as soon
        # as it's invoked (so that the proper prepared statement is cached).
        ActiveRecord::Relation.prepend(RelationQueries)
        ActiveRecord::Base.include(CoreQueries)
        ActiveRecord::Encryption::EncryptedAttributeType.prepend(ExtendedEncryptableType)
      end

      # When modifying this file run performance tests in
      # +activerecord/test/cases/encryption/performance/extended_deterministic_queries_performance_test.rb+
      # to make sure performance overhead is acceptable.
      #
      # @TODO We will extend this to support previous "encryption context" versions in future iterations
      # @TODO Experimental. Support for every kind of query is pending
      # @TODO It should not patch anything if not needed (no previous schemes or no support for previous encryption schemes)

      module EncryptedQuery # :nodoc:
        class << self
          def process_arguments(owner, args, check_for_additional_values)
            return args unless args.is_a?(Array) && (options = args.first).is_a?(Hash)

            relation = owner if owner.is_a?(Relation)
            owner = relation.model if relation

            deterministic_attributes = owner.deterministic_encrypted_attributes

            nested_conditions = relation && options.any? { |_, value| value.is_a?(Hash) }

            return args if deterministic_attributes.blank? && !nested_conditions

            options = options.transform_keys do |key|
              if key.is_a?(Array)
                key.map(&:to_s)
              else
                key.to_s
              end
            end
            args[0] = options

            deterministic_attributes&.each do |attribute_name|
              attribute_name = attribute_name.to_s
              type = owner.type_for_attribute(attribute_name)
              if !type.previous_types.empty? && value = options[attribute_name]
                options[attribute_name] = process_encrypted_query_argument(value, check_for_additional_values, type)
              end
            end

            process_nested_arguments(relation, options, check_for_additional_values) if nested_conditions

            args
          end

          private
            def process_nested_arguments(relation, options, check_for_additional_values)
              options.each do |key, nested_options|
                next unless key.is_a?(String) && nested_options.is_a?(Hash)
                next unless model = nested_model_for(relation, key)
                next if (deterministic_attributes = model.deterministic_encrypted_attributes).blank?

                expanded = nested_options

                deterministic_attributes.each do |attribute_name|
                  attribute_key = nested_options.key?(attribute_name) ? attribute_name : attribute_name.to_s
                  next unless nested_options.key?(attribute_key)

                  type = model.type_for_attribute(attribute_name)
                  next if type.previous_types.empty?

                  expanded = nested_options.dup if expanded.equal?(nested_options)
                  expanded[attribute_key] = process_encrypted_query_argument(nested_options[attribute_key], check_for_additional_values, type)
                end

                options[key] = expanded unless expanded.equal?(nested_options)
              end
            end

            def nested_model_for(relation, key)
              table = TableMetadata.new(relation.model, relation.table)
              return if table.has_column?(key)

              table.associated_table(key) { |table_name| relation.send(:lookup_table_klass_from_join_dependencies, table_name) }.klass
            end

            def process_encrypted_query_argument(value, check_for_additional_values, type)
              return value if check_for_additional_values && value.is_a?(Array) && value.last.is_a?(AdditionalValue)

              case value
              when String, Array
                list = Array(value)
                list + list.flat_map do |each_value|
                  if check_for_additional_values && each_value.is_a?(AdditionalValue)
                    each_value
                  else
                    additional_values_for(each_value, type)
                  end
                end
              else
                value
              end
            end

            def additional_values_for(value, type)
              type.previous_types.collect do |additional_type|
                AdditionalValue.new(value, additional_type)
              end
            end
        end
      end

      module RelationQueries
        def where(*args)
          super(*EncryptedQuery.process_arguments(self, args, true))
        end

        def exists?(*args)
          super(*EncryptedQuery.process_arguments(self, args, true))
        end

        def scope_for_create
          return super unless model.deterministic_encrypted_attributes&.any?

          scope_attributes = super
          wheres = where_values_hash

          model.deterministic_encrypted_attributes.each do |attribute_name|
            attribute_name = attribute_name.to_s
            values = wheres[attribute_name]
            if values.is_a?(Array) && values[1..].all?(AdditionalValue)
              scope_attributes[attribute_name] = values.first
            end
          end

          scope_attributes
        end
      end

      module CoreQueries
        extend ActiveSupport::Concern

        class_methods do
          def find_by(*args)
            super(*EncryptedQuery.process_arguments(self, args, false))
          end
        end
      end

      class AdditionalValue
        attr_reader :value, :type

        def initialize(value, type)
          @type = type
          @value = process(value)
        end

        private
          def process(value)
            type.serialize(value)
          end
      end

      module ExtendedEncryptableType
        def serialize(data)
          if data.is_a?(AdditionalValue)
            data.value
          else
            super
          end
        end
      end
    end
  end
end
