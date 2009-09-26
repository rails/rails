require 'action_controller'

module Rails
  class Application
    # Loads a Rails application from a directory and returns a Rails
    # Application object that responds to #call(env)
    def self.load(path, options = {})
      require "#{path}/config/environment"
      new(path, options)
    end

    def initialize(path, options)
      @path = path

      ensure_tmp_dirs

      if options[:config]
        config = File.join(path, options[:config])
        config = nil unless File.exist?(config)
      end

      @app = ::Rack::Builder.new {
        use Rails::Rack::LogTailer unless options[:detach]
        use Rails::Rack::Debugger if options[:debugger]
        if options[:path]
          base = options[:path]
          ActionController::Base.relative_url_root = base
        end

        map base || "/" do
          use Rails::Rack::Static 

          if config && config =~ /\.ru$/
            instance_eval(File.read(config), config)
          elsif config
            require config
            run Object.const_get(File.basename(config, '.rb').capitalize)
          else
            run ActionController::Dispatcher.new
          end
        end
      }.to_app
    end

    def call(env)
      @app.call(env)
    end

  private

    def ensure_tmp_dirs
      %w(cache pids sessions sockets).each do |dir_to_make|
        FileUtils.mkdir_p(File.join(@path, 'tmp', dir_to_make))
      end
    end

  end
end