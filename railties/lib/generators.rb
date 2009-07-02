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

module Rails
  module Generators
    # Remove builtin generators.
    #
    def self.builtin
      Dir[File.dirname(__FILE__) + '/generators/*/*'].collect do |file|
        file.split('/')[-2, 2]
      end
    end

    # Remove the color from output.
    #
    def self.no_color!
      Thor::Base.shell = Thor::Shell::Basic
    end

    # Receives a namespace and tries different combinations to find a generator.
    #
    # ==== Examples
    #
    #   find_by_namespace :webrat, :rails, :integration
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
    #   find_by_namespace "test_unit:model"
    #
    # It will search for generators at:
    #
    #   "test_unit:generators:model", "test_unit:model"
    #
    def self.find_by_namespace(name, base=nil, context=nil)
      name, attempts = name.to_s, []

      attempts << "#{base}:generators:#{name}"    if base && name.count(':') == 0
      attempts << "#{name}:generators:#{context}" if context && name.count(':') == 0
      attempts << name.sub(':', ':generators:')   if name.count(':') == 1
      attempts << name

      attempts.each do |namespace|
        klass = Thor::Util.find_by_namespace(namespace)
        return klass if klass
      end

      nil
    end

    # Show help message with available generators.
    #
    def self.help
      rails = Rails::Generators.builtin.map do |group, name|
        name if group == "rails"
      end
      rails.compact!
      rails.sort!

      puts "Please select a generator."
      puts "Builtin: #{rails.join(', ')}."

      # TODO Show others after lookup is implemented
      # puts "Others: #{others.join(', ')}."
    end

    # Receives a namespace, arguments and the behavior to invoke the generator.
    # It's used as the default entry point for generate, destroy and update
    # commands.
    #
    def self.invoke(namespace, args=ARGV, behavior=:invoke)
      # Load everything right now ...
      builtin.each do |group, name|
        require "generators/#{group}/#{name}/#{name}_generator"
      end

      if klass = find_by_namespace(namespace, "rails")
        args << "--help" if klass.arguments.any? { |a| a.required? } && args.empty?
        klass.start args, :behavior => behavior
      else
        puts "Could not find generator #{namespace}."
      end
    end
  end
end

