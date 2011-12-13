require "active_support/core_ext/array/wrap"
require "active_support/core_ext/array/extract_options"

module ActiveSupport
  # This class is responsible to track files and invoke the given block
  # whenever one of these files are changed. For example, this class
  # is used by Rails to reload the I18n framework whenever they are
  # changed upon a new request.
  #
  #   i18n_reloader = ActiveSupport::FileUpdateChecker.new(paths) do
  #     I18n.reload!
  #   end
  #
  #   ActionDispatch::Reloader.to_prepare do
  #     i18n_reloader.execute_if_updated
  #   end
  #
  class FileUpdateChecker
    # It accepts two parameters on initialization. The first is
    # the *paths* and the second is *calculate*, a boolean.
    #
    # paths must be an array of file paths but can contain a hash as
    # last argument. The hash must have directories as keys and the
    # value is an array of extensions to be watched under that directory.
    #
    # If *calculate* is true, the latest updated at will calculated
    # on initialization, therefore, the first call to execute_if_updated
    # will only evaluate the block if something really changed.
    #
    # This method must also receive a block that will be called once a file changes.
    #
    # This particular implementation checks for added files and updated files,
    # but not removed files. Directories lookup are compiled to a glob for
    # performance. Therefore, while someone can add new files to paths after
    # initialization, adding new directories is not allowed. Notice that,
    # depending on the implementation, not even new files may be added.
    def initialize(paths, calculate=false, &block)
      @paths = paths
      @glob  = compile_glob(@paths.extract_options!)
      @block = block
      @updated_at = nil
      @last_update_at = calculate ? updated_at : nil
    end

    # Check if any of the entries were updated. If so, the updated_at
    # value is cached until the block is executed via +execute+ or +execute_if_updated+
    def updated?
      current_updated_at = updated_at
      if @last_update_at != current_updated_at
        @updated_at = updated_at
        true
      else
        false
      end
    end

    # Executes the given block expiring any internal cache.
    def execute
      @last_update_at = updated_at
      @block.call
    ensure
      @updated_at = nil
    end

    # Execute the block given if updated. This call
    # always flush the cache.
    def execute_if_updated
      if updated?
        execute
        true
      else
        false
      end
    end

    private

    def updated_at #:nodoc:
      @updated_at || begin
        all = []
        all.concat @paths
        all.concat Dir[@glob] if @glob
        all.map { |path| File.mtime(path) }.max
      end
    end

    def compile_glob(hash) #:nodoc:
      hash.freeze # Freeze so changes aren't accidently pushed
      return if hash.empty?

      globs = []
      hash.each do |key, value|
        globs << "#{key}/**/*#{compile_ext(value)}"
      end
      "{#{globs.join(",")}}"
    end

    def compile_ext(array) #:nodoc:
      array = Array.wrap(array)
      return if array.empty?
      ".{#{array.join(",")}}"
    end
  end
end
