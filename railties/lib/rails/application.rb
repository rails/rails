module Rails
  class Application
    extend Initializable

    class << self
      def config
        @config ||= Configuration.new
      end

      # TODO: change the plugin loader to use config
      alias configuration config

      def config=(config)
        @config = config
      end

      def plugin_loader
        @plugin_loader ||= config.plugin_loader.new(self)
      end

      def routes
        ActionController::Routing::Routes
      end

      def middleware
        config.middleware
      end

      def call(env)
        @app ||= middleware.build(routes)
        @app.call(env)
      end

      def new
        initializers.run
        self
      end
    end

    initializer :initialize_rails do
      Rails.initializers.run
    end

    # Set the <tt>$LOAD_PATH</tt> based on the value of
    # Configuration#load_paths. Duplicates are removed.
    initializer :set_load_path do
      config.paths.add_to_load_path
      $LOAD_PATH.uniq!
    end

    # Bail if boot.rb is outdated
    initializer :freak_out_if_boot_rb_is_outdated do
      unless defined?(Rails::BOOTSTRAP_VERSION)
        abort %{Your config/boot.rb is outdated: Run "rake rails:update".}
      end
    end

    # Requires all frameworks specified by the Configuration#frameworks
    # list. By default, all frameworks (Active Record, Active Support,
    # Action Pack, Action Mailer, and Active Resource) are loaded.
    initializer :require_frameworks do
      begin
        require 'active_support'
        require 'active_support/core_ext/kernel/reporting'
        require 'active_support/core_ext/logger'

        # TODO: This is here to make Sam Ruby's tests pass. Needs discussion.
        require 'active_support/core_ext/numeric/bytes'
        config.frameworks.each { |framework| require(framework.to_s) }
      rescue LoadError => e
        # Re-raise as RuntimeError because Mongrel would swallow LoadError.
        raise e.to_s
      end
    end

    # Set the paths from which Rails will automatically load source files, and
    # the load_once paths.
    initializer :set_autoload_paths do
      require 'active_support/dependencies'
      ActiveSupport::Dependencies.load_paths = config.load_paths.uniq
      ActiveSupport::Dependencies.load_once_paths = config.load_once_paths.uniq

      extra = ActiveSupport::Dependencies.load_once_paths - ActiveSupport::Dependencies.load_paths
      unless extra.empty?
        abort <<-end_error
          load_once_paths must be a subset of the load_paths.
          Extra items in load_once_paths: #{extra * ','}
        end_error
      end

      # Freeze the arrays so future modifications will fail rather than do nothing mysteriously
      config.load_once_paths.freeze
    end

    # Adds all load paths from plugins to the global set of load paths, so that
    # code from plugins can be required (explicitly or automatically via ActiveSupport::Dependencies).
    initializer :add_plugin_load_paths do
      require 'active_support/dependencies'
      plugin_loader.add_plugin_load_paths
    end

    # Create tmp directories
    initializer :ensure_tmp_directories_exist do
      %w(cache pids sessions sockets).each do |dir_to_make|
        FileUtils.mkdir_p(File.join(configuration.root_path, 'tmp', dir_to_make))
      end
    end
  end
end
