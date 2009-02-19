require 'thread'

module Rack
  # Rack::Reloader checks on every request, but at most every +secs+
  # seconds, if a file loaded changed, and reloads it, logging to
  # rack.errors.
  #
  # It is recommended you use ShowExceptions to catch SyntaxErrors etc.

  class Reloader
    def initialize(app, secs=10)
      @app = app
      @secs = secs              # reload every @secs seconds max
      @last = Time.now
    end

    def call(env)
      if Time.now > @last + @secs
        Thread.exclusive {
          reload!(env['rack.errors'])
          @last = Time.now
        }
      end

      @app.call(env)
    end

    def reload!(stderr=$stderr)
      need_reload = $LOADED_FEATURES.find_all { |loaded|
        begin
          if loaded =~ /\A[.\/]/  # absolute filename or 1.9
            abs = loaded
          else
            abs = $LOAD_PATH.map { |path| ::File.join(path, loaded) }.
                             find { |file| ::File.exist? file }
          end

          if abs
            ::File.mtime(abs) > @last - @secs  rescue false
          else
            false
          end
        end
      }

      need_reload.each { |l|
        $LOADED_FEATURES.delete l
      }

      need_reload.each { |to_load|
        begin
          if require to_load
            stderr.puts "#{self.class}: reloaded `#{to_load}'"
          end
        rescue LoadError, SyntaxError => e
          raise e                 # Possibly ShowExceptions
        end
      }

      stderr.flush
      need_reload
    end
  end
end
