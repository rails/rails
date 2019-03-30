# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Raw
      def call(template, source)
        "#{source.inspect}.html_safe;"
      end
    end
  end
end
