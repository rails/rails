# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Html < Raw # :nodoc:
      def call(template, source)
        "ActionView::OutputBuffer.new #{super}"
      end
    end
  end
end
