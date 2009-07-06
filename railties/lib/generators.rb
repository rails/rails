activesupport_path = "#{File.dirname(__FILE__)}/../../activesupport/lib"
$:.unshift(activesupport_path) if File.directory?(activesupport_path)

begin
  require 'active_support/mini'
rescue LoadError
  require 'rubygems'
  gem 'activesupport'
  require 'active_support/mini'
end

$:.unshift(File.dirname(__FILE__))
require 'rails/version' unless defined?(Rails::VERSION)

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

require 'generators/base'
require 'generators/named_base'

module Rails
  module Generators

    # Generators load paths used on lookup. The lookup happens as:
    #
    #   1) builtin generators
    #   2) frozen gems generators
    #   3) rubygems gems generators (not available yet)
    #   4) plugin generators
    #   5) lib generators
    #   6) ~/rails/generators
    #
    # TODO Add Rubygems generators (depends on dependencies system rework)
    # TODO Remove hardcoded paths for all, except (1).
    #
    def self.load_path
      @@load_path ||= begin
        paths = []
        paths << File.expand_path(File.join(File.dirname(__FILE__), "generators"))
        if defined?(RAILS_ROOT)
          paths += Dir[File.join(RAILS_ROOT, "vendor", "gems", "*", "lib", "generators")]
          paths += Dir[File.join(RAILS_ROOT, "vendor", "plugins", "*", "lib", "generators")]
          paths << File.join(RAILS_ROOT, "lib", "generators")
        end
        paths << File.join(Thor::Util.user_home, ".rails", "generators")
        paths
      end
    end
    load_path # Cache load paths

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

      unloaded = attempts - namespaces
      lookup(unloaded)

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

      # Load paths and remove builtin
      paths, others = load_path.dup, []
      paths.shift

      paths.each do |path|
        tail = [ "*", "*", "*_generator.rb" ]

        until tail.empty?
          others += Dir[File.join(path, *tail)].collect do |file|
            file.split('/')[-tail.size, 2].join(':').sub(/_generator\.rb$/, '')
          end
          tail.shift
        end
      end

      others.sort!
      puts "Others: #{others.join(', ')}." unless others.empty?
    end

    # Receives a namespace, arguments and the behavior to invoke the generator.
    # It's used as the default entry point for generate, destroy and update
    # commands.
    #
    def self.invoke(namespace, args=ARGV, config={})
      if klass = find_by_namespace(namespace, "rails")
        args << "--help" if klass.arguments.any? { |a| a.required? } && args.empty?
        klass.start args, config
      else
        puts "Could not find generator #{namespace}."
      end
    end

    protected

      # Return all defined namespaces.
      #
      def self.namespaces
        Thor::Base.subclasses.map(&:namespace)
      end

      # Receives namespaces in an array and tries to find matching generators
      # in the load path. Each path is traversed into directory lookups. For
      # example:
      #
      #   rails:generators:model
      #
      # Becomes:
      #
      #   generators/rails/model/model_generator.rb
      #   generators/rails/model_generator.rb
      #   generators/model_generator.rb
      #
      def self.lookup(attempts)
        attempts.each do |attempt|
          generators_path = ['.']

          paths = attempt.gsub(':generators:', ':').split(':')
          name  = "#{paths.last}_generator.rb"

          until paths.empty?
            generators_path.unshift File.join(*paths)
            paths.pop
          end

          generators_path.uniq!
          generators_path = "{#{generators_path.join(',')}}"

          self.load_path.each do |path|
            Dir[File.join(path, generators_path, name)].each do |file|
              begin
                require file
              rescue Exception => e
                warn "[WARNING] Could not load generator at #{file.inspect}. Error: #{e.message}"
              end
            end
          end
        end
      end

  end
end

