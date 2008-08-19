module Rails
  module Rack
    class Logger
      EnvironmentLog = "#{File.expand_path(Rails.root)}/log/#{Rails.env}.log"

      def initialize(app, log = nil)
        @app = app
        @path = Pathname.new(log || EnvironmentLog).cleanpath
        @cursor = ::File.size(@path)
        @last_checked = Time.now
      end

      def call(env)
        response = @app.call(env)
        ::File.open(@path, 'r') do |f|
          f.seek @cursor
          if f.mtime > @last_checked
            contents = f.read
            @last_checked = f.mtime
            @cursor += contents.length
            print contents
          end
        end
        response
      end
    end
  end
end
