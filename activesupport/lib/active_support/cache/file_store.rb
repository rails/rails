require 'active_support/core_ext/marshal'
require 'active_support/core_ext/file/atomic'
require 'active_support/core_ext/string/conversions'
require 'uri/common'

module ActiveSupport
  module Cache
    # A cache store implementation which stores everything on the filesystem.
    #
    # FileStore implements the Strategy::LocalCache strategy which implements
    # an in-memory cache inside of a block.
    class FileStore < Store
      attr_reader :cache_path

      DIR_FORMATTER = "%03X"
      FILENAME_MAX_SIZE = 228 # max filename size on file system is 255, minus room for timestamp and random characters appended by Tempfile (used by atomic write)
      EXCLUDED_DIRS = ['.', '..'].freeze

      def initialize(cache_path, options = nil)
        super(options)
        @cache_path = cache_path.to_s
        extend Strategy::LocalCache
      end

      def clear(options = nil)
        root_dirs = Dir.entries(cache_path).reject {|f| (EXCLUDED_DIRS + [".gitkeep"]).include?(f)}
        FileUtils.rm_r(root_dirs.collect{|f| File.join(cache_path, f)})
      end

      def cleanup(options = nil)
        options = merged_options(options)
        each_key(options) do |key|
          entry = read_entry(key, options)
          delete_entry(key, options) if entry && entry.expired?
        end
      end

      def increment(name, amount = 1, options = nil)
        file_name = key_file_path(namespaced_key(name, options))
        lock_file(file_name) do
          options = merged_options(options)
          if num = read(name, options)
            num = num.to_i + amount
            write(name, num, options)
            num
          else
            nil
          end
        end
      end

      def decrement(name, amount = 1, options = nil)
        file_name = key_file_path(namespaced_key(name, options))
        lock_file(file_name) do
          options = merged_options(options)
          if num = read(name, options)
            num = num.to_i - amount
            write(name, num, options)
            num
          else
            nil
          end
        end
      end

      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        instrument(:delete_matched, matcher.inspect) do
          matcher = key_matcher(matcher, options)
          search_dir(cache_path) do |path|
            key = file_path_key(path)
            delete_entry(key, options) if key.match(matcher)
          end
        end
      end

      protected

        def read_entry(key, options)
          file_name = key_file_path(key)
          if File.exist?(file_name)
            File.open(file_name) { |f| Marshal.load(f) }
          end
        rescue => e
          logger.error("FileStoreError (#{e}): #{e.message}") if logger
          nil
        end

        def write_entry(key, entry, options)
          file_name = key_file_path(key)
          ensure_cache_path(File.dirname(file_name))
          File.atomic_write(file_name, cache_path) {|f| Marshal.dump(entry, f)}
          true
        end

        def delete_entry(key, options)
          file_name = key_file_path(key)
          if File.exist?(file_name)
            begin
              File.delete(file_name)
              delete_empty_directories(File.dirname(file_name))
              true
            rescue => e
              # Just in case the error was caused by another process deleting the file first.
              raise e if File.exist?(file_name)
              false
            end
          end
        end

      private
        # Lock a file for a block so only one process can modify it at a time.
        def lock_file(file_name, &block) # :nodoc:
          if File.exist?(file_name)
            File.open(file_name, 'r+') do |f|
              begin
                f.flock File::LOCK_EX
                yield
              ensure
                f.flock File::LOCK_UN
              end
            end
          else
            yield
          end
        end

        # Translate a key into a file path.
        def key_file_path(key)
          fname = URI.encode_www_form_component(key)
          hash = Zlib.adler32(fname)
          hash, dir_1 = hash.divmod(0x1000)
          dir_2 = hash.modulo(0x1000)
          fname_paths = []

          # Make sure file name doesn't exceed file system limits.
          begin
            fname_paths << fname[0, FILENAME_MAX_SIZE]
            fname = fname[FILENAME_MAX_SIZE..-1]
          end until fname.blank?

          File.join(cache_path, DIR_FORMATTER % dir_1, DIR_FORMATTER % dir_2, *fname_paths)
        end

        # Translate a file path into a key.
        def file_path_key(path)
          fname = path[cache_path.to_s.size..-1].split(File::SEPARATOR, 4).last
          URI.decode_www_form_component(fname, Encoding::UTF_8)
        end

        # Delete empty directories in the cache.
        def delete_empty_directories(dir)
          return if File.realpath(dir) == File.realpath(cache_path)
          if Dir.entries(dir).reject {|f| EXCLUDED_DIRS.include?(f)}.empty?
            Dir.delete(dir) rescue nil
            delete_empty_directories(File.dirname(dir))
          end
        end

        # Make sure a file path's directories exist.
        def ensure_cache_path(path)
          FileUtils.makedirs(path) unless File.exist?(path)
        end

        def search_dir(dir, &callback)
          return if !File.exist?(dir)
          Dir.foreach(dir) do |d|
            next if EXCLUDED_DIRS.include?(d)
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
