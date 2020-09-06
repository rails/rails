# frozen_string_literal: true

require 'active_support/test_case'
require 'active_support/testing/autorun'
require 'rails/generators/app_base'

module Rails
  module Generators
    class GeneratorTest < ActiveSupport::TestCase
      def make_builder_class
        Class.new(AppBase) do
          add_shared_options_for 'application'

          # include a module to get around thor's method_added hook
          include(Module.new {
            def gemfile_entries; super; end
            def invoke_all; super; self; end
            def add_gem_entry_filter; super; end
            def gemfile_entry(*args); super; end
          })
        end
      end

      def test_construction
        klass = make_builder_class
        assert klass.start(['new', 'blah'])
      end

      def test_add_gem
        klass = make_builder_class
        generator = klass.start(['new', 'blah'])
        generator.gemfile_entry 'tenderlove'
        assert_includes generator.gemfile_entries.map(&:name), 'tenderlove'
      end

      def test_add_gem_with_version
        klass = make_builder_class
        generator = klass.start(['new', 'blah'])
        generator.gemfile_entry 'tenderlove', '2.0.0'
        assert generator.gemfile_entries.find { |gfe|
          gfe.name == 'tenderlove' && gfe.version == '2.0.0'
        }
      end

      def test_add_github_gem
        klass = make_builder_class
        generator = klass.start(['new', 'blah'])
        generator.gemfile_entry 'tenderlove', github: 'hello world'
        assert generator.gemfile_entries.find { |gfe|
          gfe.name == 'tenderlove' && gfe.options[:github] == 'hello world'
        }
      end

      def test_add_path_gem
        klass = make_builder_class
        generator = klass.start(['new', 'blah'])
        generator.gemfile_entry 'tenderlove', path: 'hello world'
        assert generator.gemfile_entries.find { |gfe|
          gfe.name == 'tenderlove' && gfe.options[:path] == 'hello world'
        }
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

      def test_recommended_rails_versions
        klass     = make_builder_class
        generator = klass.start(['new', 'blah'])

        specifier_for = -> v { generator.send(:rails_version_specifier, Gem::Version.new(v)) }

        assert_equal '~> 4.1.13', specifier_for['4.1.13']
        assert_equal '~> 4.1.6.rc1', specifier_for['4.1.6.rc1']
        assert_equal ['~> 4.1.7', '>= 4.1.7.1'], specifier_for['4.1.7.1']
        assert_equal ['~> 4.1.7', '>= 4.1.7.1.2'], specifier_for['4.1.7.1.2']
        assert_equal ['~> 4.1.7', '>= 4.1.7.1.rc2'], specifier_for['4.1.7.1.rc2']
        assert_equal '~> 4.2.0.beta1', specifier_for['4.2.0.beta1']
        assert_equal '~> 5.0.0.beta1', specifier_for['5.0.0.beta1']
      end
    end
  end
end
