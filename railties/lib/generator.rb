activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
$:.unshift(activesupport_path) if File.directory?(activesupport_path)
require 'active_support/all'

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

$:.unshift(File.dirname(__FILE__))
require 'rails/version' unless defined?(Rails::VERSION)

require 'generator/base'
require 'generator/named_base'

module Rails
  module Generators
    def self.builtin
      Dir[File.dirname(__FILE__) + '/generator/generators/*'].collect do |file|
        File.basename(file)
      end
    end
  end
end
