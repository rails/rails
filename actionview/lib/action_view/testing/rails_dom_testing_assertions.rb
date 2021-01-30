# frozen_string_literal: true

# :markup: markdown

module ActionView
  module RailsDomTestingAssertions # :nodoc:
    extend ActiveSupport::Concern

    included do
      include Rails::Dom::Testing::Assertions

      def document_root_element
        html_document.root
      end
    end
  end
end
