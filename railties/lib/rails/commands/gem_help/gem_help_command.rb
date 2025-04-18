# frozen_string_literal: true

module Rails
  module Command
    class GemHelpCommand < Base # :nodoc:
      hide_command!

      def perform
        say self.class.class_usage
      end
    end
  end
end
