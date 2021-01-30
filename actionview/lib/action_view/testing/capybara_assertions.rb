# frozen_string_literal: true

module ActionView
  module CapybaraAssertions # :nodoc:
    extend ActiveSupport::Concern

    included do
      gem "capybara"
      require "capybara/minitest"

      include Capybara::Minitest::Assertions

      def page
        Capybara.string(html_document)
      end
    end
  end
end
