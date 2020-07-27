# frozen_string_literal: true

module ActionDispatch
  module Journey
    module PathHelper
      def path_from_string(string)
        build_path(string, {}, "/.?", true)
      end

      def build_path(path, requirements, separators, anchored)
        parser = ActionDispatch::Journey::Parser.new
        ast = parser.parse path
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
