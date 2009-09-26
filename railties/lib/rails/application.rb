require 'action_controller'

module Rails
  class Application
    def self.load(path, options = {})
      config = options[:config] || 'config.ru'
      config = File.join(path, config)

      if config =~ /\.ru$/
        cfgfile = File.read(config)
        if cfgfile[/^#\\(.*)/]
          opts.parse!($1.split(/\s+/))
        end
        inner_app = eval("::Rack::Builder.new {( " + cfgfile + "\n )}.to_app", nil, config)
      else
        require config
        inner_app = Object.const_get(File.basename(config, '.rb').capitalize)
      end
    end

    def initialize
      @app = ActionController::Dispatcher.new
    end

    def call(env)
      @app.call(env)
    end
  end
end
