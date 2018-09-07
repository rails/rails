# frozen_string_literal: true

activesupport_path = File.expand_path("../../../activesupport/lib", __dir__)
$:.unshift(activesupport_path) if File.directory?(activesupport_path) && !$:.include?(activesupport_path)

require "thor/group"
require "rails/command"

require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/kernel/singleton_class"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/indent"
require "active_support/core_ext/string/inflections"

module Rails
  module Generators
    include Rails::Command::Behavior

    autoload :Actions,         "rails/generators/actions"
    autoload :ActiveModel,     "rails/generators/active_model"
    autoload :Base,            "rails/generators/base"
    autoload :Migration,       "rails/generators/migration"
    autoload :NamedBase,       "rails/generators/named_base"
    autoload :ResourceHelpers, "rails/generators/resource_helpers"
    autoload :TestCase,        "rails/generators/test_case"

    mattr_accessor :namespace

    DEFAULT_ALIASES = {
      rails: {
        actions: "-a",
        orm: "-o",
        javascripts: "-j",
        javascript_engine: "-je",
        resource_controller: "-c",
        scaffold_controller: "-c",
        stylesheets: "-y",
        stylesheet_engine: "-se",
        scaffold_stylesheet: "-ss",
        template_engine: "-e",
        test_framework: "-t"
      },

      test_unit: {
        fixture_replacement: "-r",
      }
    }

    DEFAULT_OPTIONS = {
      rails: {
        api: false,
        assets: true,
        force_plural: false,
        helper: true,
        integration_tool: nil,
        javascripts: true,
        javascript_engine: :js,
        orm: false,
        resource_controller: :controller,
        resource_route: true,
        scaffold_controller: :scaffold_controller,
        stylesheets: true,
        stylesheet_engine: :css,
        scaffold_stylesheet: true,
        system_tests: nil,
        test_framework: nil,
        template_engine: :erb
      }
    }

    class << self
      def configure!(config) #:nodoc:
        api_only! if config.api_only
        no_color! unless config.colorize_logging
        aliases.deep_merge! config.aliases
        options.deep_merge! config.options
        fallbacks.merge! config.fallbacks
        templates_path.concat config.templates
        templates_path.uniq!
        hide_namespaces(*config.hidden_namespaces)
      end

      def templates_path #:nodoc:
        @templates_path ||= []
      end

      def aliases #:nodoc:
        @aliases ||= DEFAULT_ALIASES.dup
      end

      def options #:nodoc:
        @options ||= DEFAULT_OPTIONS.dup
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
      def fallbacks
        @fallbacks ||= {}
      end

      # Configure generators for API only applications. It basically hides
      # everything that is usually browser related, such as assets and session
      # migration generators, and completely disable helpers and assets
      # so generators such as scaffold won't create them.
      def api_only!
        hide_namespaces "assets", "helper", "css", "js"

        options[:rails].merge!(
          api: true,
          assets: false,
          helper: false,
          template_engine: nil
        )

        if ARGV.first == "mailer"
          options[:rails][:template_engine] = :erb
        end
      end

      # Remove the color from output.
      def no_color!
        Thor::Base.shell = Thor::Shell::Basic
      end

      # Returns an array of generator namespaces that are hidden.
      # Generator namespaces may be hidden for a variety of reasons.
      # Some are aliased such as "rails:migration" and can be
      # invoked with the shorter "migration", others are private to other generators
      # such as "css:scaffold".
      def hidden_namespaces
        @hidden_namespaces ||= begin
          orm      = options[:rails][:orm]
          test     = options[:rails][:test_framework]
          template = options[:rails][:template_engine]
          css      = options[:rails][:stylesheet_engine]

          [
            "rails",
            "resource_route",
            "#{orm}:migration",
            "#{orm}:model",
            "#{test}:controller",
            "#{test}:helper",
            "#{test}:integration",
            "#{test}:system",
            "#{test}:mailer",
            "#{test}:model",
            "#{test}:scaffold",
            "#{test}:view",
            "#{test}:job",
            "#{template}:controller",
            "#{template}:scaffold",
            "#{template}:mailer",
            "#{css}:scaffold",
            "#{css}:assets",
            "css:assets",
            "css:scaffold"
          ]
        end
      end

      def hide_namespaces(*namespaces)
        hidden_namespaces.concat(namespaces)
      end
      alias hide_namespace hide_namespaces

      # Show help message with available generators.
      def help(command = "generate")
        puts "Usage: rails #{command} GENERATOR [args] [options]"
        puts
        puts "General options:"
        puts "  -h, [--help]     # Print generator's options and usage"
        puts "  -p, [--pretend]  # Run but do not make any changes"
        puts "  -f, [--force]    # Overwrite files that already exist"
        puts "  -s, [--skip]     # Skip files that already exist"
        puts "  -q, [--quiet]    # Suppress status output"
        puts
        puts "Please choose a generator below."
        puts

        print_generators
      end

      def public_namespaces
        lookup!
        subclasses.map(&:namespace)
      end

      def print_generators
        sorted_groups.each { |b, n| print_list(b, n) }
      end

      def sorted_groups
        namespaces = public_namespaces
        namespaces.sort!

        groups = Hash.new { |h, k| h[k] = [] }
        namespaces.each do |namespace|
          base = namespace.split(":").first
          groups[base] << namespace
        end

        rails = groups.delete("rails")
        rails.map! { |n| n.sub(/^rails:/, "") }
        rails.delete("app")
        rails.delete("plugin")
        rails.delete("encrypted_secrets")
        rails.delete("encrypted_file")
        rails.delete("encryption_key_file")
        rails.delete("master_key")
        rails.delete("credentials")

        hidden_namespaces.each { |n| groups.delete(n.to_s) }

        [[ "rails", rails ]] + groups.sort.to_a
      end

      # Rails finds namespaces similar to Thor, it only adds one rule:
      #
      # Generators names must end with "_generator.rb". This is required because Rails
      # looks in load paths and loads the generator just before it's going to be used.
      #
      #   find_by_namespace :webrat, :rails, :integration
      #
      # Will search for the following generators:
      #
      #   "rails:webrat", "webrat:integration", "webrat"
      #
      # Notice that "rails:generators:webrat" could be loaded as well, what
      # Rails looks for is the first and last parts of the namespace.
      def find_by_namespace(name, base = nil, context = nil) #:nodoc:
        lookups = []
        lookups << "#{base}:#{name}"    if base
        lookups << "#{name}:#{context}" if context

        unless base || context
          unless name.to_s.include?(?:)
            lookups << "#{name}:#{name}"
            lookups << "rails:#{name}"
          end
          lookups << "#{name}"
        end

        lookup(lookups)

        namespaces = Hash[subclasses.map { |klass| [klass.namespace, klass] }]
        lookups.each do |namespace|
          klass = namespaces[namespace]
          return klass if klass
        end

        invoke_fallbacks_for(name, base) || invoke_fallbacks_for(context, name)
      end

      # Receives a namespace, arguments and the behavior to invoke the generator.
      # It's used as the default entry point for generate, destroy and update
      # commands.
      def invoke(namespace, args = ARGV, config = {})
        names = namespace.to_s.split(":")
        if klass = find_by_namespace(names.pop, names.any? && names.join(":"))
          args << "--help" if args.empty? && klass.arguments.any?(&:required?)
          klass.start(args, config)
        else
          options     = sorted_groups.flat_map(&:last)
          suggestion  = Rails::Command::Spellchecker.suggest(namespace.to_s, from: options)
          puts <<~MSG
            Could not find generator '#{namespace}'. Maybe you meant #{suggestion.inspect}?
            Run `rails generate --help` for more options.
          MSG
        end
      end

      private

        def print_list(base, namespaces) # :doc:
          namespaces = namespaces.reject { |n| hidden_namespaces.include?(n) }
          super
        end

        # Try fallbacks for the given base.
        def invoke_fallbacks_for(name, base)
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

        def command_type # :doc:
          @command_type ||= "generator"
        end

        def lookup_paths # :doc:
          @lookup_paths ||= %w( rails/generators generators )
        end

        def file_lookup_paths # :doc:
          @file_lookup_paths ||= [ "{#{lookup_paths.join(',')}}", "**", "*_generator.rb" ]
        end
    end
  end
end
