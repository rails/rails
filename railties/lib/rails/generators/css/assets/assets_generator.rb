require "rails/generators/named_base"

module Css
  module Generators
    class AssetsGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("../templates", __FILE__)

      def copy_stylesheet
        copy_file "stylesheet.css", File.join('app/assets/stylesheets', class_path, "#{file_name}.css")
      end
    end
  end
end
