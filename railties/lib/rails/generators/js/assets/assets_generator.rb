require "rails/generators/named_base"

module Js
  module Generators
    class AssetsGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("../templates", __FILE__)

      def copy_javascript
        copy_file "javascript.js", File.join('app/assets/javascripts', class_path, "#{file_name}.js")
      end
    end
  end
end
