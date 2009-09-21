require 'active_support/core_ext/file/atomic'

module ActiveSupport
  module Cache
    # A cache store implementation which stores everything on the filesystem.
    class FileStore < Store
      attr_reader :cache_path

      def initialize(cache_path)
        @cache_path = cache_path
      end

      # Reads a value from the cache.
      #
      # Possible options:
      # - +:expires_in+ - the number of seconds that this value may stay in
      #   the cache.
      def read(name, options = nil)
        super do
          file_name = real_file_path(name)
          expires = expires_in(options)

          if File.exist?(file_name) && (expires <= 0 || Time.now - File.mtime(file_name) < expires)
            File.open(file_name, 'rb') { |f| Marshal.load(f) }
          end
        end
      end

      # Writes a value to the cache.
      def write(name, value, options = nil)
        super do
          ensure_cache_path(File.dirname(real_file_path(name)))
          File.atomic_write(real_file_path(name), cache_path) { |f| Marshal.dump(value, f) }
          value
        end
      rescue => e
        logger.error "Couldn't create cache directory: #{name} (#{e.message})" if logger
      end

      def delete(name, options = nil)
        super do
          File.delete(real_file_path(name))
        end
      rescue SystemCallError => e
        # If there's no cache, then there's nothing to complain about
      end

      def delete_matched(matcher, options = nil)
        super do
          search_dir(@cache_path) do |f|
            if f =~ matcher
              begin
                File.delete(f)
              rescue SystemCallError => e
                # If there's no cache, then there's nothing to complain about
              end
            end
          end
        end
      end

      def exist?(name, options = nil)
        super do
          File.exist?(real_file_path(name))
        end
      end

      private
        def real_file_path(name)
          '%s/%s.cache' % [@cache_path, name.gsub('?', '.').gsub(':', '.')]
        end

        def ensure_cache_path(path)
          FileUtils.makedirs(path) unless File.exist?(path)
        end

        def search_dir(dir, &callback)
          Dir.foreach(dir) do |d|
            next if d == "." || d == ".."
            name = File.join(dir, d)
            if File.directory?(name)
              search_dir(name, &callback)
            else
              callback.call name
            end
          end
        end
    end
  end
end
