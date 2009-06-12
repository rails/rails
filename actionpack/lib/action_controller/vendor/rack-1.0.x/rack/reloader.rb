#          Copyright (c) 2009 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

require 'pathname'

module Rack

  # High performant source reloader
  #
  # This class acts as Rack middleware.
  #
  # What makes it especially suited for use in a production environment is that
  # any file will only be checked once and there will only be made one system
  # call stat(2).
  #
  # Please note that this will not reload files in the background, it does so
  # only when actively called.
  #
  # It is performing a check/reload cycle at the start of every request, but
  # also respects a cool down time, during which nothing will be done.
  class Reloader
    def initialize(app, cooldown = 10, backend = Stat)
      @app = app
      @cooldown = cooldown
      @last = (Time.now - cooldown)
      @cache = {}
      @mtimes = {}

      extend backend
    end

    def call(env)
      if @cooldown and Time.now > @last + @cooldown
        if Thread.list.size > 1
          Thread.exclusive{ reload! }
        else
          reload!
        end

        @last = Time.now
      end

      @app.call(env)
    end

    def reload!(stderr = $stderr)
      rotation do |file, mtime|
        previous_mtime = @mtimes[file] ||= mtime
        safe_load(file, mtime, stderr) if mtime > previous_mtime
      end
    end

    # A safe Kernel::load, issuing the hooks depending on the results
    def safe_load(file, mtime, stderr = $stderr)
      load(file)
      stderr.puts "#{self.class}: reloaded `#{file}'"
      file
    rescue LoadError, SyntaxError => ex
      stderr.puts ex
    ensure
      @mtimes[file] = mtime
    end

    module Stat
      def rotation
        files = [$0, *$LOADED_FEATURES].uniq
        paths = ['./', *$LOAD_PATH].uniq

        files.map{|file|
          next if file =~ /\.(so|bundle)$/ # cannot reload compiled files

          found, stat = figure_path(file, paths)
          next unless found && stat && mtime = stat.mtime

          @cache[file] = found

          yield(found, mtime)
        }.compact
      end

      # Takes a relative or absolute +file+ name, a couple possible +paths+ that
      # the +file+ might reside in. Returns the full path and File::Stat for the
      # path.
      def figure_path(file, paths)
        found = @cache[file]
        found = file if !found and Pathname.new(file).absolute?
        found, stat = safe_stat(found)
        return found, stat if found

        paths.find do |possible_path|
          path = ::File.join(possible_path, file)
          found, stat = safe_stat(path)
          return ::File.expand_path(found), stat if found
        end
      end

      def safe_stat(file)
        return unless file
        stat = ::File.stat(file)
        return file, stat if stat.file?
      rescue Errno::ENOENT, Errno::ENOTDIR
        @cache.delete(file) and false
      end
    end
  end
end
