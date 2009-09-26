module ActionDispatch
  module Utils
    # TODO: Pull this into rack core
    # http://github.com/halorgium/rack/commit/feaf071c1de743fbd10bc316830180a9af607278
    def parse_config(config)
      if config =~ /\.ru$/
        cfgfile = ::File.read(config)
        if cfgfile[/^#\\(.*)/]
          opts.parse! $1.split(/\s+/)
        end
        inner_app = eval "Rack::Builder.new {( " + cfgfile + "\n )}.to_app",
                         nil, config
      else
        require config
        inner_app = Object.const_get(::File.basename(config, '.rb').capitalize)
      end
    end
    module_function :parse_config
  end
end
