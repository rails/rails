activesupport_path = File.expand_path('../../../../activesupport/lib', __FILE__)
$:.unshift(activesupport_path) if File.directory?(activesupport_path) && !$:.include?(activesupport_path)

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/metaclass'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/inflections'

# TODO: Do not always push on vendored thor
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/vendor/thor-0.12.3/lib")
require 'rails/generators/base'
require 'rails/generators/named_base'

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

    def self.configure!(config = Rails.application.config.generators) #:nodoc:
      no_color! unless config.colorize_logging
      aliases.deep_merge! config.aliases
      options.deep_merge! config.options
    end

    def self.aliases #:nodoc:
      @aliases ||= DEFAULT_ALIASES.dup
    end

    def self.options #:nodoc:
      @options ||= DEFAULT_OPTIONS.dup
    end

    def self.gems_generators_paths #:nodoc:
      return [] unless defined?(Gem) && Gem.respond_to?(:loaded_specs)
      Gem.loaded_specs.inject([]) do |paths, (name, spec)|
        paths += Dir[File.join(spec.full_gem_path, "lib/{generators,rails_generators}")]
      end
    end

    def self.plugins_generators_paths #:nodoc:
      return [] unless defined?(Rails.root) && Rails.root
      Dir[File.join(Rails.root, "vendor", "plugins", "*", "lib", "{generators,rails_generators}")]
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
      @fallbacks ||= {}
    end

    # Remove the color from output.
    def self.no_color!
      Thor::Base.shell = Thor::Shell::Basic
    end

    # Track all generators subclasses.
    def self.subclasses
      @subclasses ||= []
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
    # TODO Remove hardcoded paths for all, except (6).
    #
    def self.load_paths
      @load_paths ||= begin
        paths = []
        paths += Dir[File.join(Rails.root, "lib", "{generators,rails_generators}")] if defined?(Rails.root) && Rails.root
        paths += Dir[File.join(Thor::Util.user_home, ".rails", "{generators,rails_generators}")]
        paths += self.plugins_generators_paths
        paths += self.gems_generators_paths
        paths << File.expand_path(File.join(File.dirname(__FILE__), "generators"))
        paths.uniq!
        paths
      end
    end
    load_paths # Cache load paths. Needed to avoid __FILE__ pointing to wrong paths.

    # Rails finds namespaces similar to thor, it only adds one rule:
    #
    # Generators names must end with "_generator.rb". This is required because Rails
    # looks in load paths and loads the generator just before it's going to be used.
    #
    # ==== Examples
    #
    #   find_by_namespace :webrat, :rails, :integration
    #
    # Will search for the following generators:
    #
    #   "rails:webrat", "webrat:integration", "webrat"
    #
    # Notice that "rails:generators:webrat" could be loaded as well, what
    # Rails looks for is the first and last parts of the namespace.
    #
    def self.find_by_namespace(name, base=nil, context=nil) #:nodoc:
      # Mount regexps to lookup
      regexps = []
      regexps << /^#{base}:[\w:]*#{name}$/    if base
      regexps << /^#{name}:[\w:]*#{context}$/ if context
      regexps << /^[(#{name}):]+$/
      regexps.uniq!

      # Check if generator happens to be loaded
      checked = subclasses.dup
      klass   = find_by_regexps(regexps, checked)
      return klass if klass

      # Try to require other generators by looking in load_paths
      lookup(name, context)
      unchecked = subclasses - checked
      klass = find_by_regexps(regexps, unchecked)
      return klass if klass

      # Invoke fallbacks
      invoke_fallbacks_for(name, base) || invoke_fallbacks_for(context, name)
    end

    # Tries to find a generator which the namespace match the regexp.
    def self.find_by_regexps(regexps, klasses)
      klasses.find do |klass|
        namespace = klass.namespace
        regexps.find { |r| namespace =~ r }
      end
    end

    # Receives a namespace, arguments and the behavior to invoke the generator.
    # It's used as the default entry point for generate, destroy and update
    # commands.
    def self.invoke(namespace, args=ARGV, config={})
      names = namespace.to_s.split(':')

      if klass = find_by_namespace(names.pop, names.shift || "rails")
        args << "--help" if klass.arguments.any? { |a| a.required? } && args.empty?
        klass.start(args, config)
      else
        puts "Could not find generator #{namespace}."
      end
    end

    # Show help message with available generators.
    def self.help
      builtin = Rails::Generators.builtin.each { |n| n.sub!(/^rails:/, '') }
      builtin.sort!

      lookup("*")
      others  = subclasses.map{ |k| k.namespace.gsub(':generators:', ':') }
      others -= Rails::Generators.builtin
      others.sort!

      puts "Please select a generator."
      puts "Builtin: #{builtin.join(', ')}."
      puts "Others: #{others.join(', ')}." unless others.empty?
    end

    protected

      # Keep builtin generators in an Array.
      def self.builtin #:nodoc:
        Dir[File.dirname(__FILE__) + '/generators/*/*'].collect do |file|
          file.split('/')[-2, 2].join(':')
        end
      end

      # Try fallbacks for the given base.
      def self.invoke_fallbacks_for(name, base) #:nodoc:
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
      # in the load path.
      def self.lookup(*attempts) #:nodoc:
        attempts.compact!
        attempts.uniq!
        attempts = "{#{attempts.join(',')}}_generator.rb"

        self.load_paths.each do |path|
          Dir[File.join(path, '**', attempts)].each do |file|
            begin
              require file
            rescue NameError => e
              raise unless e.message =~ /Rails::Generator/
              warn "[WARNING] Could not load generator at #{file.inspect} because it's a Rails 2.x generator, which is not supported anymore"
            rescue Exception => e
              warn "[WARNING] Could not load generator at #{file.inspect}. Error: #{e.message}"
            end
          end
        end
      end

  end
end

