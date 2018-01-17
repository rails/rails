# frozen_string_literal: true

require "rails/generators/named_base"

module Css # :nodoc:
  module Generators # :nodoc:
    class AssetsGenerator < Rails::Generators::NamedBase # :nodoc:
      source_root File.expand_path("templates", __dir__)

      def copy_stylesheet
        copy_file "stylesheet.css", File.join("app/assets/stylesheets", class_path, "#{file_name}.css")
      end
    end
  end
end
