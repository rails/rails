module ActiveSupport
  # FileUpdateChecker specifies the API used by Rails to watch files
  # and control reloading. The API depends on four methods:
  #
  # * +initialize+ which expects two parameters and one block as
  #   described below.
  #
  # * +updated?+ which returns a boolean if there were updates in
  #   the filesystem or not.
  #
  # * +execute+ which executes the given block on initialization
  #   and updates the latest watched files and timestamp.
  #
  # * +execute_if_updated+ which just executes the block if it was updated.
  #
  # After initialization, a call to +execute_if_updated+ must execute
  # the block only if there was really a change in the filesystem.
  #
  # This class is used by Rails to reload the I18n framework whenever
  # they are changed upon a new request.
  #
  #   i18n_reloader = ActiveSupport::FileUpdateChecker.new(paths) do
  #     I18n.reload!
  #   end
  #
  #   ActionDispatch::Reloader.to_prepare do
  #     i18n_reloader.execute_if_updated
  #   end
  #
  # One can use regex to filter or ignore particular files through the options
  # hash. For example, one could use:
  #
  #   opts = {:filter => /Gemfile/}
  #   listener = FileChangeListener.new(["/home/john/rails"], {}, opts)
  #   Thread.new do
  #     listener.start_listening
  #   end
  #
  # This would look at all of the files inside the "/home/john/rails" directory
  # and keep track of all the files that have been changed. To access the
  # changed files, one can read from the changed_files queue like so:
  #
  #   changed_file = listener.changed_files.pop()
  #
  # An alternative to creating a queue of changed files, one can elect to send
  # notifications to a particular notification group. The changed_files queue
  # will always stay empty, but the ChangedFile objects will be sent through
  # the ActiveSupport::Notifications framework. To do this, one needs to set
  # opts[:notifications] to the name of the notification group. For example:
  #
  #   opts = {:notifications => "filesystem_changes"}
  #   listener = FileChangeListener.new(["/home/john/rails"], {}, opts)
  #   Thread.new do
  #     listener.start_listening
  #   end
  #
  # In the above example, one would recieve the changed files in the
  # /home/john/rails directory if they subscribed to notifications as follows:
  #
  #   changed_files = []
  #   ActiveSupport::Notifications.subscribe("filesystem_changed") { |*args| changed_files << [*args] }
  #
  # Note that the start_listening method will continue infinitely, so it is
  # best called from within a new thread.
  class FileUpdateChecker
    # The ChangedFile class provides a means of accessing information about
    # a file which has recently been changed. The class provides information
    # about the time of the change, the path for the file which was changed
    # and the type of change (whether the file was modified, added, or
    # removed).
    class ChangedFile
      class << self
        VALID_CHANGE_TYPES = [:modified, :added, :removed]

        def notifications_hash(path, type)
          check_change_type(type)
          {:path => path, :type => type, :time => Time.now}
        end

        def check_change_type(type)
          if !VALID_CHANGE_TYPES.include?(type)
            raise ArgumentError, "Change type #{type} is invalid. Valid change types are :#{VALID_CHANGE_TYPES.join(', :')}"
          end
        end
      end

      attr_accessor :path, :time, :type

      def initialize(path, type)
        self.class.check_change_type(type)

        @path = path
        @type = type
        @time = Time.now
      end
    end

    attr_accessor :changed_files

    # It accepts two parameters on initialization. The first is an array
    # of files and the second is an optional hash of directories. The hash must
    # have directories as keys and the value is an array of extensions to be
    # watched under that directory.
    #
    # This method may also receive a block that will be called once a path
    # changes and execute or execute_if_updated is called. The array of files
    # and list of directories cannot be changed after FileUpdateChecker 
    # has been initialized.
    #
    # The options one can specify are the following:
    #
    #   :filter -> Only chooses paths matching the regex
    #
    #   :ignore -> Ignores all paths matching the regex
    #
    #   :notifications -> Give the name of the group of the notifications
    #   which you would like to call upon file change. If this field is
    #   not nil, then the changed_files queue will always be empty and changed
    #   files will be sent via the appropriate notifications. The value of
    #   this field is notifications group name to which file change
    #   notifications are sent.
    #
    #   :recurse -> If true, then all of the subdirectories of the original
    #   paths will be searched recursively in a BFS fashion. All file changes
    #   will be detected, such as additions, deletions, and modifications. 
    def initialize(paths, dirs={}, opts={}, &block)
      @paths = paths
      @dirs = dirs
      @opts = opts
      @block = block

      @start_time = Time.now
      @file_cache = ThreadSafe::Cache.new
      @changed_files = Queue.new
      @semaphore = Mutex.new

      listen_for_changes
    end

    # Starts listening to changes in the filesystem. This method is
    # synchronized until the stop_listening method is called. Once the object
    # starts listening, it goes through and checks all files that have been
    # changed since the object was created.
    #
    # If the object was previously stopped, and start_listening is called
    # again, then all of the file changes since the last stop was called will
    # be pushed to the changed_files queue. The files which were created and
    # deleted between the stop and start of the method will be ignored.
    def start_listening
      Thread.new do
        @continue_listening = true
        while @continue_listening
          listen_for_changes
        end
      end
    end

    # Stops listening to changes in the filesystem. When this method is called
    # the FileChangeListener object will finish its last pass of the
    # filesystem and stop.
    def stop_listening
      @continue_listening = false
    end

    # Check if any of the entries were updated.
    def updated?
      @changed_files.clear()
      start_size = @file_cache.size
      listen_for_changes
      end_size = @file_cache.size
      start_size != end_size || !@changed_files.empty?
    end

    # Executes the given block and updates the latest watched files and
    # timestamp.
    def execute
      listen_for_changes
      @block.call
    end

    # Execute the block given if updated.
    def execute_if_updated
      if updated?
        execute
        true
      else
        false
      end
    end

    private

    # Method which listens for changes in the file system. This method
    # delegates work to all the helper methods.
    #
    # Looks for files which have been added or modified by checking the
    # @file_cache and seeing if files have been changed since the last
    # pass. It also keeps track of @files_alive which are the files which
    # are still around in the directory. If the @file_cache has a filepath
    # which does not show up in @files_alive, that file is considered deleted.
    #
    # Note that this file is synchronized so that only a single BFS can be run
    # over the file system at a single time.
    def listen_for_changes
      @semaphore.synchronize do
        @files_alive = []

        paths = initialize_paths(@paths, @dirs)
        directories = handle_paths(paths)
        if @opts[:recurse]
          update_changed_files(directories)
        end

        deleted_files = @file_cache.keys - @files_alive.uniq
        deleted_files.each do |filename|
          @file_cache.delete(filename)
          push_changes(filename, :removed)
        end
      end
    end

    # Takes a set of directories and looks for new files in those directories.
    # Does a BFS on the set of starting directories and recursively calls
    # itself until there are no more files left.
    #
    # Each path that is found in the directory is passed through valid_path?
    # to look for new paths that are relevant. Paths are then parsed by
    # handle_paths. New directories that are found form the BFS frontier
    # and update_changed_files is called on these new directories.
    def update_changed_files(directories)
      new_directory_paths = []

      directories.each do |directory_path|
        expanded_filepaths = Dir.foreach(directory_path)
        .select { |path| valid_path?(path) }
        .map { |path| "#{directory_path}/#{path}" }

        new_directory_paths += handle_paths(expanded_filepaths)
      end

      update_changed_files(new_directory_paths) if new_directory_paths.any?
    end

    # Checks whether the path is valid based on the filters and ignores
    # that were passed in as options on object initialization.
    #
    # The method also removes .. and . as valid paths since they lead
    # to up and down directories.
    def valid_path?(path)
      if path == ".." || path == "."
        return false
      end

      validations = []
      if @opts[:filter]
        validations << (path =~ @opts[:filter])
      end
      if @opts[:ignore]
        validations << (path !~ @opts[:ignore])
      end

      validations.all?
    end

    # Requires an array of filepaths. The filepaths must be valid objects
    # in the filesystem.
    #
    # This method checks to see whether each filepath is a directory or
    # whether it is a file. If it is a file, then it checks for changes
    # using the check_file_for_changes submethod. If it is a directory,
    # the method appends the filepath to a list and returns that list.
    def handle_paths(expanded_filepaths)
      files, new_directories = expanded_filepaths.partition { |fp| File.file?(fp) }

      files.each do |filepath|
        @files_alive << filepath
        check_file_for_changes(filepath)
      end

      new_directories
    end

    # Requires a filepath, and checks to see whether that file has been
    # changed since the last BFS scan. This checks for changed files
    # by placing the last time the file was modified into the cache.
    # Each BFS scan then checks if the modified time is greater than
    # it was previously.
    #
    # If the method detects a change, then a ChangedFile object is created
    # with the path to the file and the type of change it was. The object
    # is then pushed onto the @changed_files queue.
    def check_file_for_changes(filepath)
      last_modified = File.mtime(filepath)

      if @file_cache[filepath] != last_modified && @start_time <= last_modified
        change_type = (@file_cache[filepath] ? :modified : :added)
        push_changes(filepath, change_type)
      end

      @file_cache[filepath] = last_modified
    end

    # Pushes the changes in the filesystem to either the ActiveSupport
    # Notifications system, or creates a ChangedFile object and sends it to
    # the changed_files queue.
    def push_changes(filepath, change_type)
      if @opts[:notifications]
        ActiveSupport::Notifications.instrument(@opts[:notifications],
                ChangedFile.notifications_hash(filepath, change_type))
      else
        changed_file = ChangedFile.new(filepath, change_type)
        @changed_files.push(changed_file)
      end
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

    def initialize_paths(paths, dirs)
      glob = compile_glob(dirs)
      glob ? Array(paths) + Dir[glob] : Array(paths)
    end
  end
end
