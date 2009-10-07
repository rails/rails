module Rails
  class Application
    extend Initializable

    def self.inherited(child)
      child.initializers = initializers.dup
    end

    def self.config
      @config ||= Configuration.new
    end

    def self.config=(config)
      @config = config
    end

    def self.routes
      ActionController::Routing::Routes
    end

    def self.middleware
      config.middleware
    end

    def self.call(env)
      @app ||= middleware.build(routes)
      @app.call(env)
    end

    def self.new
      initializers.run
      self
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
  end
end
