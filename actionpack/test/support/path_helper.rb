# frozen_string_literal: true

module ActionDispatch
  module Journey
    module PathHelper
      def path_from_string(string)
        build_path(string, {}, "/.?", true)
      end

      def build_path(path, requirements, separators, anchored, formatted = true)
        parser = ActionDispatch::Journey::Parser.new
        ast = parser.parse path
        ast = Journey::Ast.new(ast, formatted)
        ActionDispatch::Journey::Path::Pattern.new(
          ast,
          requirements,
          separators,
          anchored
        )
      end
    end
  end
end
