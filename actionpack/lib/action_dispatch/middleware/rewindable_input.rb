module ActionDispatch
  class RewindableInput
    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        env['rack.input'].rewind
      rescue NoMethodError, Errno::ESPIPE
        # Handles exceptions raised by input streams that cannot be rewound
        # such as when using plain CGI under Apache
        env['rack.input'] = StringIO.new(env['rack.input'].read)
      end

      @app.call(env)
    end
  end
end
