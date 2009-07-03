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
require 'generators/active_record' # We will need ActionORM from ActiveRecord, but just it.

module Rails
  module Generators
    mattr_accessor :load_path

    # Generators load paths. First search on generators in the RAILS_ROOT, then
    # look for them in rails generators.
    #
    def self.load_path
      @@load_path ||= begin
        paths = []
        paths << File.expand_path(File.join(File.dirname(__FILE__), "generators"))
        paths << File.join(RAILS_ROOT, "lib", "generators") if defined?(RAILS_ROOT)
        paths
      end
    end
    load_path # Cache load paths

    # Receives paths in an array and tries to find generators for it in the load
    # path.
    #
    def self.lookup(attempts)
      generators_path = []

      # Traverse attempts into directory lookups. For example:
      #
      #   rails:generators:model
      #
      # Becomes:
      #
      #   generators/rails/model/model_generator.rb
      #   generators/rails/model_generator.rb
      #   generators/model_generator.rb
      #
      attempts.each do |attempt|
        paths = attempt.gsub(':generators:', ':').split(':')
        paths << "#{paths.last}_generator.rb"

        until paths.empty?
          generators_path << File.join(*paths)
          paths.delete_at(-1) unless paths.delete_at(-2)
        end
      end

      generators_path.uniq!
      generators_path.each do |generator_path|
        self.load_path.each do |path|
          Dir[File.join(path, generator_path)].each do |file|
            require file
          end
        end
      end
    end

    # Keep builtin generators in an Array[Array[group, name]].
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

      if name.count(':') == 0
        attempts << "#{base}:generators:#{name}"    if base
        attempts << "#{name}:generators:#{context}" if context
      end
      attempts << name.sub(':', ':generators:') if name.count(':') == 1
      attempts << name

      unless klass = find_many_by_namespace(attempts)
        lookup(attempts)
        klass = find_many_by_namespace(attempts)
      end
      klass
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
      if klass = find_by_namespace(namespace, "rails")
        args << "--help" if klass.arguments.any? { |a| a.required? } && args.empty?
        klass.start args, :behavior => behavior
      else
        puts "Could not find generator #{namespace}."
      end
    end

    protected

      def self.find_many_by_namespace(attempts)
        attempts.each do |namespace|
          klass = Thor::Util.find_by_namespace(namespace)
          return klass if klass
        end
        nil
      end

  end
end

