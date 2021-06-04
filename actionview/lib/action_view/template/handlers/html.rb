# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Html < Raw
      def call(template, source)
        "ActionView::OutputBuffer.new #{super}"
      end
    end
  end
end
