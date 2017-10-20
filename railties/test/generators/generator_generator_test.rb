# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/generator/generator_generator"

class GeneratorGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(awesome)

  def test_generator_skeleton_is_created
    run_generator

    %w(
      lib/generators/awesome
      lib/generators/awesome/USAGE
      lib/generators/awesome/templates
    ).each { |path| assert_file path }

    assert_file "lib/generators/awesome/awesome_generator.rb",
                /class AwesomeGenerator < Rails::Generators::NamedBase/
    assert_file "test/lib/generators/awesome_generator_test.rb",
               /class AwesomeGeneratorTest < Rails::Generators::TestCase/,
               /require 'generators\/awesome\/awesome_generator'/
  end

  def test_namespaced_generator_skeleton
    run_generator ["rails/awesome"]

    %w(
      lib/generators/rails/awesome
      lib/generators/rails/awesome/USAGE
      lib/generators/rails/awesome/templates
    ).each { |path| assert_file path }

    assert_file "lib/generators/rails/awesome/awesome_generator.rb",
                /class Rails::AwesomeGenerator < Rails::Generators::NamedBase/
    assert_file "test/lib/generators/rails/awesome_generator_test.rb",
               /class Rails::AwesomeGeneratorTest < Rails::Generators::TestCase/,
               /require 'generators\/rails\/awesome\/awesome_generator'/
  end

  def test_generator_skeleton_is_created_without_file_name_namespace
    run_generator ["awesome", "--namespace", "false"]

    %w(
      lib/generators/
      lib/generators/USAGE
      lib/generators/templates
    ).each { |path| assert_file path }

    assert_file "lib/generators/awesome_generator.rb",
                /class AwesomeGenerator < Rails::Generators::NamedBase/
    assert_file "test/lib/generators/awesome_generator_test.rb",
               /class AwesomeGeneratorTest < Rails::Generators::TestCase/,
               /require 'generators\/awesome_generator'/
  end

  def test_namespaced_generator_skeleton_without_file_name_namespace
    run_generator ["rails/awesome", "--namespace", "false"]

    %w(
      lib/generators/rails
      lib/generators/rails/USAGE
      lib/generators/rails/templates
    ).each { |path| assert_file path }

    assert_file "lib/generators/rails/awesome_generator.rb",
                /class Rails::AwesomeGenerator < Rails::Generators::NamedBase/
    assert_file "test/lib/generators/rails/awesome_generator_test.rb",
               /class Rails::AwesomeGeneratorTest < Rails::Generators::TestCase/,
               /require 'generators\/rails\/awesome_generator'/
  end
end
