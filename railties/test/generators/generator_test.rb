require 'active_support/test_case'
require 'active_support/testing/autorun'
require 'rails/generators/app_base'

module Rails
  module Generators
    class GeneratorTest < ActiveSupport::TestCase
      def make_builder_class
        klass = Class.new(AppBase) do
          add_shared_options_for "application"

          # include a module to get around thor's method_added hook
          include(Module.new {
            def gemfile_entries; super; end
            def invoke_all; super; self; end
            def add_gem_entry_filter; super; end
          })
        end
      end

      def test_construction
        klass     = make_builder_class
        assert klass.start(['new', 'blah'])
      end

      def test_filter
        klass     = make_builder_class
        generator = klass.start(['new', 'blah'])
        gems      = generator.gemfile_entries
        generator.add_gem_entry_filter { |gem|
          gem.name != gems.first.name
        }
        assert_equal gems.drop(1), generator.gemfile_entries
      end

      def test_two_filters
        klass     = make_builder_class
        generator = klass.start(['new', 'blah'])
        gems      = generator.gemfile_entries
        generator.add_gem_entry_filter { |gem|
          gem.name != gems.first.name
        }
        generator.add_gem_entry_filter { |gem|
          gem.name != gems[1].name
        }
        assert_equal gems.drop(2), generator.gemfile_entries
      end
    end
  end
end
