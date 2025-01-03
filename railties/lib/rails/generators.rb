# frozen_string_literal: true

require "thor/group"
require "rails/command"

require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/enumerable"
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
    autoload :Database,        "rails/generators/database"
    autoload :AppName,         "rails/generators/app_name"
    autoload :NamedBase,       "rails/generators/named_base"
    autoload :ResourceHelpers, "rails/generators/resource_helpers"
    autoload :TestCase,        "rails/generators/test_case"

    mattr_accessor :namespace

    DEFAULT_ALIASES = {
      rails: {
        actions: "-a",
        orm: "-o",
        javascripts: ["-j", "--js"],
        resource_controller: "-c",
        scaffold_controller: "-c",
        stylesheets: "-y",
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
        orm: false,
        resource_controller: :controller,
        resource_route: true,
        scaffold_controller: :scaffold_controller,
        system_tests: nil,
        test_framework: nil,
        template_engine: :erb
      }
    }

    # We need to store the RAILS_DEV_PATH in a constant, otherwise the path
    # can change when we FileUtils.cd.
    RAILS_DEV_PATH = File.expand_path("../../..", __dir__) # :nodoc:

    class << self
      def configure!(config) # :nodoc:
        api_only! if config.api_only
        no_color! unless config.colorize_logging
        aliases.deep_merge! config.aliases
        options.deep_merge! config.options
        fallbacks.merge! config.fallbacks
        templates_path.concat config.templates
        templates_path.uniq!
        hide_namespaces(*config.hidden_namespaces)
        after_generate_callbacks.replace config.after_generate_callbacks
      end

      def templates_path # :nodoc:
        @templates_path ||= []
      end

      def aliases # :nodoc:
        @aliases ||= DEFAULT_ALIASES.dup
      end

      def options # :nodoc:
        @options ||= DEFAULT_OPTIONS.dup
      end

      def after_generate_callbacks # :nodoc:
        @after_generate_callbacks ||= []
      end

      # Hold configured generators fallbacks. If a plugin developer wants a
      # generator group to fall back to another group in case of missing generators,
      # they can add a fallback.
      #
      # For example, shoulda is considered a +test_framework+ and is an extension
      # of +test_unit+. However, most part of shoulda generators are similar to
      # +test_unit+ ones.
      #
      # Shoulda then can tell generators to search for +test_unit+ generators when
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

        options[:mailer] ||= {}
        options[:mailer][:template_engine] ||= :erb
      end

      # Returns an array of generator namespaces that are hidden.
      # Generator namespaces may be hidden for a variety of reasons.
      # Some are aliased such as "rails:migration" and can be
      # invoked with the shorter "migration".
      def hidden_namespaces
        @hidden_namespaces ||= begin
          orm      = options[:rails][:orm]
          test     = options[:rails][:test_framework]
          template = options[:rails][:template_engine]

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
            "action_text:install",
            "action_mailbox:install",
            "devcontainer"
          ].tap do |h|
            h << "test_unit" if test.to_s != "test_unit"
          end
        end
      end

      def hide_namespaces(*namespaces)
        hidden_namespaces.concat(namespaces)
      end
      alias hide_namespace hide_namespaces

      # Show help message with available generators.
      def help(command = "generate")
        puts "Usage:"
        puts "  bin/rails #{command} GENERATOR [args] [options]"
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
        rails.map! { |n| n.delete_prefix("rails:") }
        rails.delete("app")
        rails.delete("plugin")
        rails.delete("encrypted_file")
        rails.delete("encryption_key_file")
        rails.delete("master_key")
        rails.delete("credentials")
        rails.delete("db:system:change")

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
      def find_by_namespace(name, base = nil, context = nil) # :nodoc:
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

        namespaces = subclasses.index_by(&:namespace)
        lookups.each do |namespace|
          klass = namespaces[namespace]
          return klass if klass
        end

        invoke_fallbacks_for(name, base) || invoke_fallbacks_for(context, name)
      end

      # Receives a namespace, arguments, and the behavior to invoke the generator.
      # It's used as the default entry point for generate, destroy, and update
      # commands.
      def invoke(namespace, args = ARGV, config = {})
        names = namespace.to_s.split(":")
        if klass = find_by_namespace(names.pop, names.any? && names.join(":"))
          args << "--help" if args.empty? && klass.arguments.any?(&:required?)
          klass.start(args, config)
          run_after_generate_callback if config[:behavior] == :invoke
        else
          options = sorted_groups.flat_map(&:last)
          error = Command::CorrectableNameError.new("Could not find generator '#{namespace}'.", namespace, options)

          puts <<~MSG
            #{error.detailed_message}
            Run `bin/rails generate --help` for more options.
          MSG
          exit 1
        end
      end

      def add_generated_file(file) # :nodoc:
        (@@generated_files ||= []) << file
        file
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

        def run_after_generate_callback
          if defined?(@@generated_files) && !@@generated_files.empty?
            @after_generate_callbacks.each do |callback|
              callback.call(@@generated_files)
            end
            @@generated_files = []
          end
        end
    end
  end
end
