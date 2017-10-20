# frozen_string_literal: true

module ActionController
  module Testing
    extend ActiveSupport::Concern

    # Behavior specific to functional tests
    module Functional # :nodoc:
      def recycle!
        @_url_options = nil
        self.formats = nil
        self.params = nil
      end
    end
  end
end
