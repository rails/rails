# frozen_string_literal: true

require "rails/generators/active_record"

module ActiveRecord
  module Generators # :nodoc:
    class MultiDbGenerator < ::Rails::Generators::Base # :nodoc:
      source_root File.expand_path("templates", __dir__)

      def create_multi_db
        filename = "multi_db.rb"
        template filename, "config/initializers/#{filename}"
      end
    end
  end
end
