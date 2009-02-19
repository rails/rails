module Rack
  # Rack::Builder implements a small DSL to iteratively construct Rack
  # applications.
  #
  # Example:
  #
  #  app = Rack::Builder.new {
  #    use Rack::CommonLogger
  #    use Rack::ShowExceptions
  #    map "/lobster" do
  #      use Rack::Lint
  #      run Rack::Lobster.new
  #    end
  #  }
  #
  # Or
  #
  #  app = Rack::Builder.app do
  #    use Rack::CommonLogger
  #    lambda { |env| [200, {'Content-Type' => 'text/plain'}, 'OK'] }
  #  end
  #
  # +use+ adds a middleware to the stack, +run+ dispatches to an application.
  # You can use +map+ to construct a Rack::URLMap in a convenient way.

  class Builder
    def initialize(&block)
      @ins = []
      instance_eval(&block) if block_given?
    end

    def self.app(&block)
      self.new(&block).to_app
    end

    def use(middleware, *args, &block)
      @ins << if block_given?
        lambda { |app| middleware.new(app, *args, &block) }
      else
        lambda { |app| middleware.new(app, *args) }
      end
    end

    def run(app)
      @ins << app #lambda { |nothing| app }
    end

    def map(path, &block)
      if @ins.last.kind_of? Hash
        @ins.last[path] = self.class.new(&block).to_app
      else
        @ins << {}
        map(path, &block)
      end
    end

    def to_app
      @ins[-1] = Rack::URLMap.new(@ins.last)  if Hash === @ins.last
      inner_app = @ins.last
      @ins[0...-1].reverse.inject(inner_app) { |a, e| e.call(a) }
    end

    def call(env)
      to_app.call(env)
    end
  end
end
