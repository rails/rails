# frozen_string_literal: true

require "active_support/test_case"
require "active_support/testing/autorun"
require "env_helpers"
require "minitest/mock"
require "rails/generators/app_base"

module Rails
  module Generators
    class GeneratorTest < ActiveSupport::TestCase
      include EnvHelpers

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

      def test_version_manager_ruby_version_with_rbenv_env_var
        klass = make_builder_class
        generator = klass.start(["new", "blah"])

        switch_env "RBENV_VERSION", "3.4.0" do
          assert_equal "3.4.0", generator.send(:version_manager_ruby_version)
        end
      end

      def test_version_manager_ruby_version_with_rvm_env_var
        klass = make_builder_class
        generator = klass.start(["new", "blah"])

        switch_env "RBENV_VERSION", nil do
          switch_env "rvm_ruby_string", "ruby-3.4.0" do
            assert_equal "ruby-3.4.0", generator.send(:version_manager_ruby_version)
          end
        end
      end

      def test_version_manager_ruby_version_with_mri_ruby
        klass = make_builder_class
        generator = klass.start(["new", "blah"])


        switch_env "RBENV_VERSION", nil do
          switch_env "rvm_ruby_string", nil do
            stub_const(Object, :RUBY_ENGINE, "ruby") do
              Gem.stub(:ruby_version, Gem::Version.new("3.4.0")) do
                assert_equal "ruby-3.4.0", generator.send(:version_manager_ruby_version)
              end
            end
          end
        end
      end

      def test_version_manager_ruby_version_with_mri_ruby_prerelease
        klass = make_builder_class
        generator = klass.start(["new", "blah"])

        switch_env "RBENV_VERSION", nil do
          switch_env "rvm_ruby_string", nil do
            stub_const(Object, :RUBY_ENGINE, "ruby") do
              Gem.stub(:ruby_version, Gem::Version.new("4.0.0.preview2")) do
                assert_equal "ruby-4.0.0-preview2", generator.send(:version_manager_ruby_version)
              end
            end
          end
        end
      end

      def test_version_manager_ruby_version_with_non_mri_ruby
        klass = make_builder_class
        generator = klass.start(["new", "blah"])

        switch_env "RBENV_VERSION", nil do
          switch_env "rvm_ruby_string", nil do
            stub_const(Object, :RUBY_ENGINE, "jruby") do
              stub_const(Object, :RUBY_ENGINE_VERSION, "10.0.2.0") do
                assert_equal "jruby-10.0.2.0", generator.send(:version_manager_ruby_version)
              end
            end
          end
        end
      end
    end
  end
end
