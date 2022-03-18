# frozen_string_literal: true

require "abstract_unit"
require "tmpdir"

module PluginTestHelper
  def create_test_file(name, pass: true)
    plugin_file "test/#{name}_test.rb", <<-RUBY
      require "test_helper"

      class #{name.camelize}Test < ActiveSupport::TestCase
        def test_truth
          puts "#{name.camelize}Test"
          assert #{pass}, 'wups!'
        end
      end
    RUBY
  end

  def plugin_file(path, contents, mode: "w")
    FileUtils.mkdir_p File.dirname("#{plugin_path}/#{path}")
    File.open("#{plugin_path}/#{path}", mode) do |f|
      f.puts contents
    end
  end

  def fill_in_gemspec_fields(gemspec_path = "#{plugin_path}/#{File.basename plugin_path}.gemspec")
    # Some fields must be a valid URL.
    filled_in = File.read(gemspec_path).gsub(/"TODO.*"/, "http://example.com".inspect)
    File.write(gemspec_path, filled_in)
  end

  def resolve_rails_gem_to_repository(gemfile_path = "#{plugin_path}/Gemfile")
    repository_path = File.expand_path("../../..", __dir__)
    File.write(gemfile_path, "gem 'rails', path: #{repository_path.inspect}\n", mode: "a")
  end
end
