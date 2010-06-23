require "rails/plugin"

module Rails
  class Plugin
    class Loader
      attr_reader :initializer

      # Creates a new Plugin::Loader instance, associated with the given
      # Rails::Initializer. This default implementation automatically locates
      # all plugins, and adds all plugin load paths, when it is created. The plugins
      # are then fully loaded (init.rb is evaluated) when load_plugins is called.
      #
      # It is the loader's responsibility to ensure that only the plugins specified
      # in the configuration are actually loaded, and that the order defined
      # is respected.
      def initialize(initializer)
        @initializer = initializer
      end

      # Returns the plugins to be loaded, in the order they should be loaded.
      def plugins
        @plugins ||= all_plugins.select { |plugin| should_load?(plugin) }.sort { |p1, p2| order_plugins(p1, p2) }
      end

      # Returns the plugins that are in engine-form (have an app/ directory)
      def engines
        @engines ||= plugins.select(&:engine?)
      end

      # Returns all the plugins that could be found by the current locators.
      def all_plugins
        @all_plugins ||= locate_plugins
        @all_plugins
      end

      def load_plugins
        plugins.each do |plugin|
          plugin.load(initializer)
          register_plugin_as_loaded(plugin)
        end

        configure_engines

        ensure_all_registered_plugins_are_loaded!
      end

      # Adds the load paths for every plugin into the $LOAD_PATH. Plugin load paths are
      # added *after* the application's <tt>lib</tt> directory, to ensure that an application
      # can always override code within a plugin.
      #
      # Plugin load paths are also added to Dependencies.autoload_paths, and Dependencies.autoload_once_paths.
      def add_plugin_load_paths
        plugins.each do |plugin|
          plugin.load_paths.each do |path|
            $LOAD_PATH.insert(application_lib_index + 1, path)

            ActiveSupport::Dependencies.autoload_paths << path

            unless configuration.reload_plugins?
              ActiveSupport::Dependencies.autoload_once_paths << path
            end
          end
        end

        $LOAD_PATH.uniq!
      end

      def engine_metal_paths
        engines.collect(&:metal_path)
      end

      protected
        def configure_engines
          if engines.any?
            add_engine_routing_configurations
            add_engine_locales
            add_engine_controller_paths
            add_engine_view_paths
          end
        end

        def add_engine_routing_configurations
          engines.select(&:routed?).collect(&:routing_file).each do |routing_file|
            ActionController::Routing::Routes.add_configuration_file(routing_file)
          end
        end

        def add_engine_locales
          # reverse it such that the last engine can overwrite translations from the first, like with routes
          locale_files = engines.select(&:localized?).collect(&:locale_files).reverse.flatten
          I18n.load_path += locale_files - I18n.load_path
        end

        def add_engine_controller_paths
          ActionController::Routing.controller_paths += engines.collect(&:controller_path)
        end

        def add_engine_view_paths
          # reverse it such that the last engine can overwrite view paths from the first, like with routes
          paths = ActionView::PathSet.new(engines.collect(&:view_path).reverse)
          ActionController::Base.view_paths.concat(paths)
          ActionMailer::Base.view_paths.concat(paths) if configuration.frameworks.include?(:action_mailer)
        end

        # The locate_plugins method uses each class in config.plugin_locators to
        # find the set of all plugins available to this Rails application.
        def locate_plugins
          configuration.plugin_locators.map do |locator|
            locator.new(initializer).plugins
          end.flatten
          # TODO: sorting based on config.plugins
        end

        def register_plugin_as_loaded(plugin)
          initializer.loaded_plugins << plugin
        end

        def configuration
          initializer.configuration
        end

        def should_load?(plugin)
          # uses Plugin#name and Plugin#valid?
          enabled?(plugin) && plugin.valid?
        end

        def order_plugins(plugin_a, plugin_b)
          if !explicit_plugin_loading_order?
            plugin_a <=> plugin_b
          else
            if !explicitly_enabled?(plugin_a) && !explicitly_enabled?(plugin_b)
              plugin_a <=> plugin_b
            else
              effective_order_of(plugin_a) <=> effective_order_of(plugin_b)
            end
          end
        end

        def effective_order_of(plugin)
          if explicitly_enabled?(plugin)
            registered_plugin_names.index(plugin.name)
          else
            registered_plugin_names.index('all')
          end
        end

        def application_lib_index
          $LOAD_PATH.index(File.join(RAILS_ROOT, 'lib')) || 0
        end

        def enabled?(plugin)
          !explicit_plugin_loading_order? || registered?(plugin)
        end

        def explicit_plugin_loading_order?
          !registered_plugin_names.nil?
        end

        def registered?(plugin)
          explicit_plugin_loading_order? && registered_plugins_names_plugin?(plugin)
        end

        def explicitly_enabled?(plugin)
          !explicit_plugin_loading_order? || explicitly_registered?(plugin)
        end

        def explicitly_registered?(plugin)
          explicit_plugin_loading_order? && registered_plugin_names.include?(plugin.name)
        end

        def registered_plugins_names_plugin?(plugin)
          registered_plugin_names.include?(plugin.name) || registered_plugin_names.include?('all')
        end

        # The plugins that have been explicitly listed with config.plugins. If this list is nil
        # then it means the client does not care which plugins or in what order they are loaded,
        # so we load all in alphabetical order. If it is an empty array, we load no plugins, if it is
        # non empty, we load the named plugins in the order specified.
        def registered_plugin_names
          configuration.plugins ? configuration.plugins.map(&:to_s) : nil
        end

        def loaded?(plugin_name)
          initializer.loaded_plugins.detect { |plugin| plugin.name == plugin_name.to_s }
        end

        def ensure_all_registered_plugins_are_loaded!
          if explicit_plugin_loading_order?
            if configuration.plugins.detect {|plugin| plugin != :all && !loaded?(plugin) }
              missing_plugins = configuration.plugins - (plugins.map{|p| p.name.to_sym} + [:all])
              raise LoadError, "Could not locate the following plugins: #{missing_plugins.to_sentence(:locale => :en)}"
            end
          end
        end

    end
  end
end
