# frozen_string_literal: true

require "rails/test_unit/runner"

module Rails
  module LineFiltering # :nodoc:
    def run(reporter, options = {})
      options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))

      super
    end
  end
end
