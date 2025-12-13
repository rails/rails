# frozen_string_literal: true

require "rails/test_unit/runner"

module Rails
  module LineFiltering # :nodoc:
    def self.extended(obj)
      require "minitest"

      case Minitest::VERSION
      when /^5/ then
        obj.extend MT5
      when /^6/ then
        obj.extend MT6
      end
    end

    module MT5
      def run(reporter, options = {})
        options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))

        super
      end
    end

    module MT6
      def run_suite(reporter, options = {})
        options = options.merge(include: Rails::TestUnit::Runner.compose_filter(self, options[:include]))

        super
      end
    end
  end
end
