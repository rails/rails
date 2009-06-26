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
require 'generators/erb'
require 'generators/test_unit'

module Rails
  module Generators
    def self.builtin
      Dir[File.dirname(__FILE__) + '/generators/*/*'].collect do |file|
        file.split('/')[-2, 2]
      end
    end

    # Receives a namespace and tries different combinations to find a generator.
    #
    # ==== Examples
    #
    #   lookup_by_namespace :webrat, :rails, :integration
    #
    # Will search for the following generators:
    #
    #   "rails:generators:webrat", "webrat:generators:integration", "webrat"
    #
    # If the namespace has ":" included we consider that a absolute namespace
    # was given and the lookup above does not happen. Just the name is searched.
    #
    # Finally, it deals with one kind of shortcut:
    #
    #   lookup_by_namespace "test_unit:model"
    #
    # It will search for generators at:
    #
    #   "test_unit:generators:model", "test_unit:model"
    #
    def self.find_by_namespace(name, base=nil, context=nil)
      attempts = [ ]
      attempts << "#{base}:generators:#{name}"    if base && name.count(':') == 0
      attempts << "#{name}:generators:#{context}" if context && name.count(':') == 0
      attempts << name.sub(':', ':generators:')   if name.count(':') == 1
      attempts << name

      attempts.each do |namespace|
        klass, task = Thor::Util.find_by_namespace(namespace)
        return klass if klass
      end

      nil
    end
  end
end

