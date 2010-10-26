module Rails
  module Rack
    class LogTailer
      def initialize(app, log = nil)
        @app = app

        path = Pathname.new(log || "#{File.expand_path(Rails.root)}/log/#{Rails.env}.log").cleanpath
        @cursor = ::File.size(path)

        @file = ::File.open(path, 'r')
      end

      def call(env)
        response = @app.call(env)
        tail!
        response
      end

      def tail!
        @file.seek @cursor

        unless @file.eof?
          contents = @file.read
          @cursor = @file.tell
          $stdout.print contents
        end
      end
    end
  end
end
