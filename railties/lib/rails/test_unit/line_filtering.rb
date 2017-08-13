require "method_source"
require_relative "runner"

module Rails
  module LineFiltering # :nodoc:
    def run(reporter, options = {})
      options[:filter] = Rails::TestUnit::Runner.compose_filter(self, options[:filter])

      super
    end
  end
end
