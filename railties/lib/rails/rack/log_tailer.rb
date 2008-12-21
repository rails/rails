module Rails
  module Rack
    class LogTailer
      EnvironmentLog = "#{File.expand_path(Rails.root)}/log/#{Rails.env}.log"

      def initialize(app, log = nil)
        @app = app

        path = Pathname.new(log || EnvironmentLog).cleanpath
        @cursor = ::File.size(path)
        @last_checked = Time.now.to_f

        @file = ::File.open(path, 'r')
      end

      def call(env)
        response = @app.call(env)
        tail_log
        response
      end

      def tail_log
        @file.seek @cursor

        mod = @file.mtime.to_f
        if mod > @last_checked
          contents = @file.read
          @last_checked = mod
          @cursor += contents.size
          $stdout.print contents
        end
      end
    end
  end
end
