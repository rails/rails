require 'active_support/file_update_monitor'
require 'active_support/core_ext/time/calculations'
require 'active_support/deprecation'

module ActiveSupport
  module FileUpdateMonitor
    class Classic < Base
      def initialize(files, dirs = {}, &block)
        @files = files.freeze
        @glob  = compile_glob(dirs)
        @block = block

        @watched    = nil
        @updated_at = nil

        @last_watched   = watched
        @last_update_at = updated_at(@last_watched)
      end

      # Check if any of the entries were updated. If so, the watched and/or
      # updated_at values are cached until the block is executed via +execute+
      # or +execute_if_updated+.
      def updated?
        current_watched = watched
        if @last_watched.size != current_watched.size
          @watched = current_watched
          true
        else
          current_updated_at = updated_at(current_watched)
          if @last_update_at < current_updated_at
            @watched    = current_watched
            @updated_at = current_updated_at
            true
          else
            false
          end
        end
      end

      # Executes the given block and updates the latest watched files and
      # timestamp.
      def execute
        @last_watched   = watched
        @last_update_at = updated_at(@last_watched)
        @block.call
      ensure
        @watched = nil
        @updated_at = nil
      end

      # Execute the block given if updated.
      def execute_if_updated
        if updated?
          yield if block_given?
          execute
          true
        else
          false
        end
      end

      private

      def watched
        @watched || begin
          all = @files.select { |f| File.exist?(f) }
          all.concat(Dir[@glob]) if @glob
          all
        end
      end

      def updated_at(paths)
        @updated_at || max_mtime(paths) || Time.at(0)
      end

      # This method returns the maximum mtime of the files in +paths+, or +nil+
      # if the array is empty.
      #
      # Files with a mtime in the future are ignored. Such abnormal situation
      # can happen for example if the user changes the clock by hand. It is
      # healthy to consider this edge case because with mtimes in the future
      # reloading is not triggered.
      def max_mtime(paths)
        time_now = Time.now
        max_mtime = nil

        # Time comparisons are performed with #compare_without_coercion because
        # AS redefines these operators in a way that is much slower and does not
        # bring any benefit in this particular code.
        #
        # Read t1.compare_without_coercion(t2) < 0 as t1 < t2.
        paths.each do |path|
          mtime = File.mtime(path)

          next if time_now.compare_without_coercion(mtime) < 0

          if max_mtime.nil? || max_mtime.compare_without_coercion(mtime) < 0
            max_mtime = mtime
          end
        end

        max_mtime
      end

      def compile_glob(hash)
        hash.freeze # Freeze so changes aren't accidentally pushed
        return if hash.empty?

        globs = hash.map do |key, value|
          "#{escape(key)}/**/*#{compile_ext(value)}"
        end
        "{#{globs.join(",")}}"
      end

      def escape(key)
        key.gsub(',','\,')
      end

      def compile_ext(array)
        array = Array(array)
        return if array.empty?
        ".{#{array.join(",")}}"
      end
    end
  end

  FileUpdateChecker = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActiveSupport::FileUpdateChecker', 'ActiveSupport::FileUpdateMonitor::Classic')
end
