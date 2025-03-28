# frozen_string_literal: true

require "active_storage/models/blob"
require "active_storage/models/attachment"
require "active_storage/models/variant_record"

# = Active Storage \Generators \Models
module ActiveStorage::Creators
  class Jobs
    class << self
      JOB_TYPES = [:mirror].freeze

      private_constant :JOB_TYPES

      def call!
        ActiveStorage.database_configs.each do |db_hash|
          name = db_hash[:name]

          JOB_TYPES.each { |type| create_job!(type, name) }
        end
      end

      private

      def create_job!(type, name)
        class_name = name == :default ? "#{type.to_s.capitalize}Job" : "#{name.to_s.camelize}::#{type.to_s.capitalize}Job"
        blob_class_name = name == :default ? "ActiveStorage::Blob" : "ActiveStorage::#{name.to_s.camelize}Blob"

        ActiveStorage.module_eval(
          <<~CODE
            #{"module #{name.to_s.camelize}" if name != :default}
              class #{type.to_s.capitalize}Job < ActiveJob::Base; end
            #{"end" if name != :default}
          CODE
        )

        klass = "ActiveStorage::#{class_name}".constantize

        klass.class_eval(<<~STR
            def self.blob_class
              #{blob_class_name}
            end
          STR
        )

        klass.include("ActiveStorage::Jobs::#{type.to_s.capitalize}".constantize)
      end
    end
  end
end
