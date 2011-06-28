require "rails/generators/named_base"

module Css
  module Generators
    class ScaffoldGenerator < Rails::Generators::NamedBase
      # In order to allow the Sass generators to pick up the default Rails CSS and
      # transform it, we leave it in a standard location for the CSS stylesheet
      # generators to handle. For the simple, default case, just copy it over.
      def copy_stylesheet
        dir = Rails::Generators::ScaffoldGenerator.source_root
        file = File.join(dir, "scaffold.css")
        create_file "app/assets/stylesheets/scaffold.css", File.read(file)
      end
    end
  end
end
