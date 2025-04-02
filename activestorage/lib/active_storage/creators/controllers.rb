# frozen_string_literal: true

require "active_storage/controllers/blobs/direct_uploads"
require "active_storage/controllers/blobs/disk"
require "active_storage/controllers/blobs/proxy"
require "active_storage/controllers/blobs/redirect"
require "active_storage/controllers/representations/base"
require "active_storage/controllers/representations/proxy"
require "active_storage/controllers/representations/redirect"
require "active_storage/controllers/base_controller"

# = Active Storage \Generators \Models
module ActiveStorage::Creators
  class Controllers
    class << self
      CONTROLLER_TYPES = {
        blobs: [
          :direct_uploads,
          :disk,
          :proxy,
          :redirect
        ],
        representations: [
          :proxy,
          :redirect
        ]
      }.freeze

      private_constant :CONTROLLER_TYPES

      def call!
        ActiveStorage.database_configs.each do |db_hash|
          name = db_hash[:name]

          CONTROLLER_TYPES.each do |type, controllers|
            controllers.each { |controller| create_controller!(type, controller, name) }
          end
        end
      end

      private

      def create_controller!(type, controller_name, name)
        class_name, blob_class_name = if name == :default
          sanitized_type = [:disk, :direct_uploads].include?(controller_name) ? nil : "#{type.to_s.camelize}::"
          [
            "#{sanitized_type}#{controller_name.to_s.camelize}Controller",
            "ActiveStorage::Blob",
          ]
        else
          sanitized_type = [:disk, :direct_uploads].include?(controller_name) ? nil : "#{type.to_s.camelize}::"
          [
            "#{name.to_s.camelize}::#{sanitized_type}#{controller_name.to_s.camelize}Controller",
            "ActiveStorage::#{name.to_s.camelize}Blob",
          ]
        end

        ActiveStorage.module_eval(
          <<~CODE
            #{"module #{name.to_s.camelize}" if name != :default}
              #{"module #{type.to_s.camelize}" if [:disk, :direct_uploads].exclude?(controller_name)}
                class #{controller_name.to_s.camelize}Controller < ActiveStorage::BaseController; end
              #{"end" if [:disk, :direct_uploads].exclude?(controller_name)}
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

        if type == :representations
          klass.include(ActiveStorage::Controllers::Representations::Base)
        end

        klass.include("ActiveStorage::Controllers::#{type.to_s.camelize}::#{controller_name.to_s.camelize}".constantize)
      end
    end
  end
end
