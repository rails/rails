# frozen_string_literal: true

require "rails/generators/named_base"

module Rails
  module Generators
    class ScriptGenerator < NamedBase
      def generate_script
        template("script.rb.tt", "script/#{file_path}.rb")
      end

      private
        def depth
          class_path.size + 1
        end
    end
  end
end
