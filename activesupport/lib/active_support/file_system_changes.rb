module ActiveSupport
  module FileSystemChanges
    class ChangedFile
      attr_accessor :path, :time, :type

      VALID_CHANGE_TYPES = [:modified, :added, :removed]

      def initialize(path, type)
        check_change_type(type)

        @path = path
        @type = type
        @time = Time.now
      end

      private

      def check_change_type(type)
        if !VALID_CHANGE_TYPES.include?(type)
          raise ArgumentError, "Change type #{type} is invalid. Valid change types are :#{VALID_CHANGE_TYPES.join(', :')}"
        end
      end
    end

    class FileSystemListener
      attr_accessor :changed_files

      def initialize(initial_paths=[], opts={})
        @paths = Array(initial_paths)
        @opts = opts

        @file_change_times = Hash.new(Time.now)
        @changed_files = Queue.new
      end

      def start_listening
        @continue_listening = true
        while @continue_listening
          listen_for_changes
        end
      end

      def stop_listening
        @continue_listening = false
      end

      private

      def listen_for_changes
        @files_alive = Set.new([])

        directories = handle_paths(@paths)
        find_changed_files(directories)

        deleted_files = @file_change_times.delete_if do |key, _|
          !@files_alive.include?(key)
        end
        deleted_files.each do |filename|
          @changed_files.push(ChangedFile.new(filename, :deleted))
        end
      end

      def find_changed_files(directories)
        new_directory_paths = []

        directories.each do |directory_path|
          expanded_filepaths = Dir.foreach(directory_path)
            .select { |path| valid_path?(path) }
            .map { |path| "#{directory_path}/#{path}" }

          new_directory_paths += handle_paths(expanded_filepaths)
        end

        find_changed_files(new_directory_paths) if new_directory_paths.any?
      end

      def valid_path?(path)
        # FIXME: Hacks to get around the up and down directories
        if path == ".." || path == "."
          return false
        end

        validations = []
        if @opts[:filter]
          validations << (path =~ @opts[:filter])
        end
        if @opts[:ignore]
          validations << !(path =~ @opts[:ignore])
        end

        validations.all?
      end

      def handle_paths(expanded_filepaths)
        new_directory_paths = []

        expanded_filepaths.each do |expanded_filepath|
          if File.file?(expanded_filepath)
            check_file_for_changes(expanded_filepath)
          elsif File.directory?(expanded_filepath)
            new_directory_paths << expanded_filepath
          end
        end

        new_directory_paths
      end

      def check_file_for_changes(filepath)
        last_modified = File.mtime(filepath)

        if @file_change_times[filepath] < last_modified
          change_type = (@file_change_times[filepath] == @file_change_times.default ? :added : :modified)
          @changed_files.push(ChangedFile.new(filepath, change_type))
          @files_alive.add(filepath)
        end

        @file_change_times[filepath] = last_modified
      end
    end
  end
end
