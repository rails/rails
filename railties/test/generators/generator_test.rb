# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_support/test_case"
require "active_support/testing/autorun"
require "rails/generators/app_base"

module Rails
  module Generators
    class GeneratorTest < ActiveSupport::TestCase
      def make_builder_class
        Class.new(AppBase) do
          add_shared_options_for "application"

          # include a module to get around thor's method_added hook
          include(Module.new {
            def gemfile_entries; super; end
            def invoke_all; super; self; end
          })
        end
      end

      def test_construction
        klass = make_builder_class
        assert klass.start(["new", "blah"])
      end

      def test_recommended_rails_versions
        klass     = make_builder_class
        generator = klass.start(["new", "blah"])

        specifier_for = -> v { generator.send(:rails_version_specifier, Gem::Version.new(v)) }

        assert_equal "~> 4.1.13", specifier_for["4.1.13"]
        assert_equal "~> 4.1.6.rc1", specifier_for["4.1.6.rc1"]
        assert_equal ["~> 4.1.7", ">= 4.1.7.1"], specifier_for["4.1.7.1"]
        assert_equal ["~> 4.1.7", ">= 4.1.7.1.2"], specifier_for["4.1.7.1.2"]
        assert_equal ["~> 4.1.7", ">= 4.1.7.1.rc2"], specifier_for["4.1.7.1.rc2"]
        assert_equal "~> 4.2.0.beta1", specifier_for["4.2.0.beta1"]
        assert_equal "~> 5.0.0.beta1", specifier_for["5.0.0.beta1"]
      end
    end
  end
end
