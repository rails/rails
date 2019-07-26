# frozen_string_literal: true

require "rails/generators/active_record"

module ActiveRecord
  module Generators # :nodoc:
    class ApplicationRecordGenerator < ::Rails::Generators::Base # :nodoc:
      source_root File.expand_path("templates", __dir__)

      # FIXME: Change this file to a symlink once RubyGems 2.5.0 is required.
      def create_application_record
        template "application_record.rb", application_record_file_name
      end

      private
        def application_record_file_name
          @application_record_file_name ||=
            if namespaced?
              "app/models/#{namespaced_path}/application_record.rb"
            else
              "app/models/application_record.rb"
            end
        end
    end
  end
end
