# frozen_string_literal: true

require "rails/generators/named_base"

module Rails
  module Generators
    class ScriptGenerator < NamedBase
      class_option :prefix, type: :boolean, aliases: "--pre", default: false,
                            desc: "Add a numbered prefix in script file name"

      def generate_script
        template("script.rb.tt", "script/#{file_path}.rb")
      end

      private
        def file_name
          [prefix, super].compact.join("_")
        end

        def prefix
          sprintf("%.3d", current_script_number + 1) if options[:prefix]
        end

        def current_script_number
          class_path.join("/")
            .then { |dir_path| Dir.glob("script/#{dir_path}/[0-9]*_*.rb") }
            .map { |file| File.basename(file).split("_").first.to_i }
            .max.to_i
        end

        def depth
          class_path.size + 1
        end
    end
  end
end
