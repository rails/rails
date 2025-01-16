# frozen_string_literal: true

require "active_support/core_ext/file/atomic"
require "active_support/core_ext/string/conversions"
require "uri/common"

module ActiveSupport
  module Cache
    # = \File \Cache \Store
    #
    # A cache store implementation which stores everything on the filesystem.
    class FileStore < Store
      attr_reader :cache_path

      DIR_FORMATTER = "%03X"
      FILENAME_MAX_SIZE = 226 # max filename size on file system is 255, minus room for timestamp, pid, and random characters appended by Tempfile (used by atomic write)
      FILEPATH_MAX_SIZE = 900 # max is 1024, plus some room
      GITKEEP_FILES = [".gitkeep", ".keep"].freeze

      def initialize(cache_path, **options)
        super(options)
        @cache_path = cache_path.to_s
      end

      # Advertise cache versioning support.
      def self.supports_cache_versioning?
        true
      end

      # Deletes all items from the cache. In this case it deletes all the entries in the specified
      # file store directory except for .keep or .gitkeep. Be careful which directory is specified in your
      # config file when using +FileStore+ because everything in that directory will be deleted.
      def clear(options = nil)
        root_dirs = (Dir.children(cache_path) - GITKEEP_FILES)
        FileUtils.rm_r(root_dirs.collect { |f| File.join(cache_path, f) })
      rescue Errno::ENOENT, Errno::ENOTEMPTY
      end

      # Preemptively iterates through all stored keys and removes the ones which have expired.
      def cleanup(options = nil)
        options = merged_options(options)
        search_dir(cache_path) do |fname|
          entry = read_entry(fname, **options)
          delete_entry(fname, **options) if entry && entry.expired?
        end
      end

      # Increment a cached integer value. Returns the updated value.
      #
      # If the key is unset, it starts from +0+:
      #
      #   cache.increment("foo") # => 1
      #   cache.increment("bar", 100) # => 100
      #
      # To set a specific value, call #write:
      #
      #   cache.write("baz", 5)
      #   cache.increment("baz") # => 6
      #
      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:increment, key, amount: amount) do
          modify_value(name, amount, options)
        end
      end

      # Decrement a cached integer value. Returns the updated value.
      #
      # If the key is unset, it will be set to +-amount+.
      #
      #   cache.decrement("foo") # => -1
      #
      # To set a specific value, call #write:
      #
      #   cache.write("baz", 5)
      #   cache.decrement("baz") # => 4
      #
      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument(:decrement, key, amount: amount) do
          modify_value(name, -amount, options)
        end
      end

      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        matcher = key_matcher(matcher, options)

        instrument(:delete_matched, matcher.inspect) do
          search_dir(cache_path) do |path|
            key = file_path_key(path)
            delete_entry(path, **options) if key.match(matcher)
          end
        end
      end

      def inspect # :nodoc:
        "#<#{self.class.name} cache_path=#{@cache_path}, options=#{@options.inspect}>"
      end

      private
        def read_entry(key, **options)
          if payload = read_serialized_entry(key, **options)
            entry = deserialize_entry(payload)
            entry if entry.is_a?(Cache::Entry)
          end
        end

        def read_serialized_entry(key, **)
          File.binread(key) if File.exist?(key)
        rescue => error
          logger.error("FileStoreError (#{error}): #{error.message}") if logger
          nil
        end

        def write_entry(key, entry, **options)
          write_serialized_entry(key, serialize_entry(entry, **options), **options)
        end

        def write_serialized_entry(key, payload, **options)
          return false if options[:unless_exist] && File.exist?(key)
          ensure_cache_path(File.dirname(key))
          File.atomic_write(key, cache_path) { |f| f.write(payload) }
          true
        end

        def delete_entry(key, **options)
          if File.exist?(key)
            begin
              File.delete(key)
              delete_empty_directories(File.dirname(key))
              true
            rescue
              # Just in case the error was caused by another process deleting the file first.
              raise if File.exist?(key)
              false
            end
          else
            false
          end
        end

        # Lock a file for a block so only one process can modify it at a time.
        def lock_file(file_name, &block)
          if File.exist?(file_name)
            File.open(file_name, "r+") do |f|
              f.flock File::LOCK_EX
              yield
            ensure
              f.flock File::LOCK_UN
            end
          else
            yield
          end
        end

        # Translate a key into a file path.
        def normalize_key(key, options)
          key = super
          fname = URI.encode_www_form_component(key)

          if fname.size > FILEPATH_MAX_SIZE
            fname = ActiveSupport::Digest.hexdigest(key)
          end

          hash = Zlib.adler32(fname)
          hash, dir_1 = hash.divmod(0x1000)
          dir_2 = hash.modulo(0x1000)

          # Make sure file name doesn't exceed file system limits.
          if fname.length < FILENAME_MAX_SIZE
            fname_paths = fname
          else
            fname_paths = []
            begin
              fname_paths << fname[0, FILENAME_MAX_SIZE]
              fname = fname[FILENAME_MAX_SIZE..-1]
            end until fname.blank?
          end

          File.join(cache_path, DIR_FORMATTER % dir_1, DIR_FORMATTER % dir_2, fname_paths)
        end

        # Translate a file path into a key.
        def file_path_key(path)
          fname = path[cache_path.to_s.size..-1].split(File::SEPARATOR, 4).last.delete(File::SEPARATOR)
          URI.decode_www_form_component(fname, Encoding::UTF_8)
        end

        # Delete empty directories in the cache.
        def delete_empty_directories(dir)
          return if File.realpath(dir) == File.realpath(cache_path)
          if Dir.children(dir).empty?
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
          Dir.each_child(dir) do |d|
            name = File.join(dir, d)
            if File.directory?(name)
              search_dir(name, &callback)
            else
              callback.call name
            end
          end
        end

        # Modifies the amount of an integer value that is stored in the cache.
        # If the key is not found it is created and set to +amount+.
        def modify_value(name, amount, options)
          options = merged_options(options)
          key = normalize_key(name, options)
          version = normalize_version(name, options)
          amount = Integer(amount)

          lock_file(key) do
            entry = read_entry(key, **options)

            if !entry || entry.expired? || entry.mismatched?(version)
              write(name, amount, options)
              amount
            else
              num = entry.value.to_i + amount
              entry = Entry.new(num, expires_at: entry.expires_at, version: entry.version)
              write_entry(key, entry)
              num
            end
          end
        end
    end
  end
end
