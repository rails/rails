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

require 'vendor/thor-0.11.5/lib/thor'
require 'generators/base'
require 'generators/named_base'

module Rails
  module Generators
    DEFAULT_ALIASES = {
      :rails => {
        :actions => '-a',
        :orm => '-o',
        :resource_controller => '-c',
        :scaffold_controller => '-c',
        :stylesheets => '-y',
        :template_engine => '-e',
        :test_framework => '-t'
      },

      :test_unit => {
        :fixture_replacement => '-r',
      },

      :plugin => {
        :generator => '-g',
        :tasks => '-r'
      }
    }

    DEFAULT_OPTIONS = {
      :active_record => {
        :migration  => true,
        :timestamps => true
      },

      :erb => {
        :form => false,
        :layout => true
      },

      :rails => {
        :force_plural => false,
        :helper => true,
        :layout => true,
        :orm => :active_record,
        :integration_tool => :test_unit,
        :performance_tool => :test_unit,
        :resource_controller => :controller,
        :scaffold_controller => :scaffold_controller,
        :singleton => false,
        :stylesheets => true,
        :template_engine => :erb,
        :test_framework => :test_unit
      },

      :test_unit => {
        :fixture => true,
        :fixture_replacement => nil
      },

      :plugin => {
        :generator => false,
        :tasks => false
      }
    }

    def self.aliases #:nodoc:
      @@aliases ||= DEFAULT_ALIASES.dup
    end

    def self.options #:nodoc:
      @@options ||= DEFAULT_OPTIONS.dup
    end

    # Get paths only from loaded rubygems. In other words, to use rspec
    # generators, you first have to ensure that rspec gem was already loaded.
    #
    def self.rubygems_generators_paths
      paths = []
      return paths unless defined?(Gem)

      Gem.loaded_specs.each do |name, spec|
        generator_path = File.join(spec.full_gem_path, "lib/generators")
        paths << generator_path if File.exist?(generator_path)
      end

      paths
    end

    # If RAILS_ROOT is defined, add vendor/gems, vendor/plugins and lib/generators
    # paths.
    #
    def self.rails_root_generators_paths
      paths = []
      if defined?(RAILS_ROOT)
        paths += Dir[File.join(RAILS_ROOT, "vendor", "gems", "gems", "*", "lib", "generators")]
        paths += Dir[File.join(RAILS_ROOT, "vendor", "plugins", "*", "lib", "generators")]
        paths << File.join(RAILS_ROOT, "lib", "generators")
      end
      paths
    end

    # Hold configured generators fallbacks. If a plugin developer wants a
    # generator group to fallback to another group in case of missing generators,
    # they can add a fallback.
    #
    # For example, shoulda is considered a test_framework and is an extension
    # of test_unit. However, most part of shoulda generators are similar to
    # test_unit ones.
    #
    # Shoulda then can tell generators to search for test_unit generators when
    # some of them are not available by adding a fallback:
    #
    #   Rails::Generators.fallbacks[:shoulda] = :test_unit
    #
    def self.fallbacks
      @@fallbacks ||= {}
    end

    # Remove the color from output.
    #
    def self.no_color!
      Thor::Base.shell = Thor::Shell::Basic
    end

    # Generators load paths used on lookup. The lookup happens as:
    #
    #   1) lib generators
    #   2) vendor/plugin generators
    #   3) vendor/gems generators
    #   4) ~/rails/generators
    #   5) rubygems generators
    #   6) builtin generators
    #
    # TODO Remove hardcoded paths for all, except (1).
    #
    def self.load_paths
      @@load_paths ||= begin
        paths = self.rails_root_generators_paths
        paths << File.join(Thor::Util.user_home, ".rails", "generators")
        paths += self.rubygems_generators_paths
        paths << File.expand_path(File.join(File.dirname(__FILE__), "generators"))
        paths
      end
    end
    load_paths # Cache load paths. Needed to avoid __FILE__ pointing to wrong paths.

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
    def self.find_by_namespace(name, base=nil, context=nil) #:nodoc:
      name, attempts = name.to_s, []

      case name.count(':')
        when 1
          base, name = name.split(':')
          return find_by_namespace(name, base)
        when 0
          attempts << "#{base}:generators:#{name}"    if base
          attempts << "#{name}:generators:#{context}" if context
      end

      attempts << name
      unloaded = attempts - namespaces
      lookup(unloaded)

      attempts.each do |namespace|
        klass = Thor::Util.find_by_namespace(namespace)
        return klass if klass
      end

      invoke_fallbacks_for(name, base)
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
      paths, others = load_paths.dup, []
      paths.pop

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

    protected

      # Return all defined namespaces.
      #
      def self.namespaces #:nodoc:
        Thor::Base.subclasses.map{ |klass| klass.namespace }
      end

      # Keep builtin generators in an Array[Array[group, name]].
      #
      def self.builtin #:nodoc:
        Dir[File.dirname(__FILE__) + '/generators/*/*'].collect do |file|
          file.split('/')[-2, 2]
        end
      end

      # Try callbacks for the given base.
      #
      def self.invoke_fallbacks_for(name, base)
        return nil unless base && fallbacks[base.to_sym]
        invoked_fallbacks = []

        Array(fallbacks[base.to_sym]).each do |fallback|
          next if invoked_fallbacks.include?(fallback)
          invoked_fallbacks << fallback

          klass = find_by_namespace(name, fallback)
          return klass if klass
        end

        nil
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
      def self.lookup(attempts) #:nodoc:
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

          self.load_paths.each do |path|
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

