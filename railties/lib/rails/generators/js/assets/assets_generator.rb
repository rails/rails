# frozen_string_literal: true

require "rails/generators/named_base"

module Js # :nodoc:
  module Generators # :nodoc:
    class AssetsGenerator < Rails::Generators::NamedBase # :nodoc:
      source_root File.expand_path("templates", __dir__)

      def copy_javascript
        copy_file "javascript.js", File.join("app/assets/javascripts", class_path, "#{file_name}.js")
      end
    end
  end
end
