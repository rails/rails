activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
$:.unshift(activesupport_path) if File.directory?(activesupport_path)
require 'active_support/all'

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

$:.unshift(File.dirname(__FILE__))
require 'rails/version' unless defined?(Rails::VERSION)

require 'generators/base'
require 'generators/named_base'
require 'generators/test_unit'

module Rails
  module Generators
    def self.builtin
      Dir[File.dirname(__FILE__) + '/generators/*/*'].collect do |file|
        file.split('/')[-2, 2]
      end
    end
  end
end

