# frozen_string_literal: true

require "active_storage/models/blob"
require "active_storage/models/attachment"
require "active_storage/models/variant_record"

# = Active Storage \Generators \Models
module ActiveStorage::Creators
  class Models
    class << self
      MODEL_TYPES = [:blob, :attachment, :variant_record].freeze

      private_constant :MODEL_TYPES

      def call!
        ActiveStorage.database_configs.each do |db_hash|
          name, connection_class = db_hash.values_at(:name, :connection_class)

          # We need to create the class first, because we need to use it to fill classes' relations
          MODEL_TYPES.each { |type| create_class!(type, name, connection_class) }
          MODEL_TYPES.each { |type| fill_class!(type, name, connection_class) }
        end

        ActiveStorage.blob_classes.each do |klass|
          ActiveSupport.run_load_hooks :active_storage_blob, klass
        end
      end

      private

      def create_class!(type, name, connection_class)
        class_name = name == :default ? "#{type.to_s.camelize}" : "#{name.to_s.camelize}#{type.to_s.camelize}"

        ActiveStorage.module_eval("class #{class_name} < ActiveStorage::Record; end")
      end

      def fill_class!(type, name, connection_class)
        class_name = name == :default ? "#{type.to_s.camelize}" : "#{name.to_s.camelize}#{type.to_s.camelize}"

        klass = "ActiveStorage::#{class_name}".constantize

        if connection_class != "ActiveRecord::Base"
          klass.class_eval("self.connection_specification_name = #{connection_class}.name")
        end

        if type == :blob
          attachment_class_name = name == :default ? "ActiveStorage::Attachment" : "ActiveStorage::#{name.to_s.camelize}Attachment"
          variant_record_class_name = name == :default ? "ActiveStorage::VariantRecord" : "ActiveStorage::#{name.to_s.camelize}VariantRecord"
          klass.class_eval("def self.attachment_class_name; '#{attachment_class_name}'; end")
          klass.class_eval("def self.variant_record_class_name; '#{variant_record_class_name}'; end")
        end

        if [:attachment, :variant_record].include?(type)
          blob_class_name = name == :default ? "ActiveStorage::Blob" : "ActiveStorage::#{name.to_s.camelize}Blob"
          klass.class_eval("def self.blob_class_name; '#{blob_class_name}'; end")
        end

        klass.class_eval("self.table_name = 'active_storage_#{type.to_s.pluralize}'")

        klass.include("ActiveStorage::Models::#{type.to_s.camelize}".constantize)

        klass.class_eval(<<~STR
          def prefix
            '#{name}'
          end
        STR
        )

        ActiveStorage::FixtureSet.singleton_class.class_eval do
          define_method(:"#{klass.name.demodulize.underscore}") do |filename:, **attributes|
            new.prepare klass.new(filename: filename, key: generate_unique_secure_token), **attributes
          end
        end

        ActiveStorage.send("#{type}_classes") << klass
      end
    end
  end
end
