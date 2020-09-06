# frozen_string_literal: true

require 'abstract_unit'
require 'tmpdir'

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

  def plugin_file(path, contents, mode: 'w')
    FileUtils.mkdir_p File.dirname("#{plugin_path}/#{path}")
    File.open("#{plugin_path}/#{path}", mode) do |f|
      f.puts contents
    end
  end
end
