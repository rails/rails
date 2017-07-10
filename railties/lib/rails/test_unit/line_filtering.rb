require 'method_source'
require "rails/test_unit/runner"

module Rails
  module LineFiltering # :nodoc:
    def run(reporter, options = {})
      options[:filter] = Rails::TestUnit::Runner.compose_filter(self, options[:filter])

      super
    end
  end
end
