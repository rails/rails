# Automatically expand encrypted arguments to support querying both encrypted and unencrypted data
#
# Active Record Encryption supports querying the db using deterministic attributes. For example:
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
# * ActiveRecord::Base: Used in +Contact.find_by_email_address(...)+
# * ActiveRecord::Relation: Used in +Contact.internal.find_by_email_address(...)+
#
# +ActiveRecord::Base+ relies on +ActiveRecord::Relation+ (+ActiveRecord::QueryMethods+) but it does
# some prepared statements caching. That's why we need to intercept +ActiveRecord::Base+ as soon
# as it's invoked (so that the proper prepared statement is cached).
#
# When modifying this file run performance tests in +test/performance/extended_deterministic_queries_performance_test.rb+ to
#   make sure performance overhead is acceptable.
#
# We will extend this to support previous "encryption context" versions in future iterations
#
# @todo This is experimental stuff. Works for our cases but full support for every kind of query is pending
module ActiveRecord
  module Encryption
    module ExtendedDeterministicQueries
      def self.install_support
        ActiveRecord::Relation.prepend(RelationQueries)
        ActiveRecord::Base.include(CoreQueries)
        ActiveRecord::Encryption::EncryptedAttributeType.prepend(ExtendedEncryptableType)
      end

      module EncryptedQueryArgumentProcessor
        private
          def process_encrypted_query_arguments(args, check_for_skipped_values)
            if args.is_a?(Array) && (options = args.first).is_a?(Hash)
              self.deterministic_encrypted_attributes&.each do |attribute_name|
                type = type_for_attribute(attribute_name)
                if value = options[attribute_name]
                  options[attribute_name] = process_encrypted_query_argument(value, check_for_skipped_values, type)
                end
              end
            end
          end

          def process_encrypted_query_argument(value, check_for_skipped_values, type)
            return value if check_for_skipped_values && value.is_a?(Array) && value.last.is_a?(AdditionalValue)

            case value
              when String, Array
                list = Array(value)
                list + list.flat_map do |each_value|
                  if check_for_skipped_values && each_value.is_a?(AdditionalValue)
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
            type.previous_types.including(clean_text_type_for(type)).collect do |additional_type|
              AdditionalValue.new(value, additional_type)
            end
          end

          def clean_text_type_for(type)
            ActiveRecord::Encryption::EncryptedAttributeType.new(downcase: type.downcase, context: { encryptor: null_encryptor })
          end

          def null_encryptor
            @null_encryptor ||= ActiveRecord::Encryption::NullEncryptor.new
          end
      end

      module RelationQueries
        include EncryptedQueryArgumentProcessor

        def where(*args)
          process_encrypted_query_arguments(args, true) unless self.deterministic_encrypted_attributes&.empty?
          super
        end

        def find_or_create_by(attributes, &block)
          find_by(attributes.dup) || create(attributes, &block)
        end

        def find_or_create_by!(attributes, &block)
          find_by(attributes.dup) || create!(attributes, &block)
        end
      end

      module CoreQueries
        extend ActiveSupport::Concern

        class_methods do
          include EncryptedQueryArgumentProcessor

          def find_by(*args)
            process_encrypted_query_arguments(args, false) unless self.deterministic_encrypted_attributes&.empty?
            super
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
