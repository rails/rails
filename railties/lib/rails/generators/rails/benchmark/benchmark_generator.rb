# frozen_string_literal: true

require "rails/generators/named_base"

module Rails
  module Generators
    class BenchmarkGenerator < NamedBase
      IPS_GEM_NAME = "benchmark-ips"

      argument :reports, type: :array, default: ["before", "after"]

      def generate_layout
        add_ips_to_gemfile unless ips_installed?
        template("benchmark.rb.tt", "script/benchmarks/#{file_name}.rb")
      end

    private
      def add_ips_to_gemfile
        gem(IPS_GEM_NAME, group: [:development, :test])
      end

      def ips_installed?
        in_root do
          return File.read("Gemfile").match?(/gem.*\b#{IPS_GEM_NAME}\b.*/)
        end
      end
    end
  end
end
