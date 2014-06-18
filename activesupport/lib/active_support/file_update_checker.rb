require "active_support/core_ext/array/wrap"
require "active_support/core_ext/array/extract_options"

module ActiveSupport
  # \FileUpdateChecker specifies the API used by Rails to watch files
  # and control reloading. The API depends on four methods:
  #
  # * +initialize+ which expects two parameters and one block as
  #   described below;
  #
  # * +updated?+ which returns a boolean if there were updates in
  #   the filesystem or not;
  #
  # * +execute+ which executes the given block on initialization
  #   and updates the counter to the latest timestamp;
  #
  # * +execute_if_updated+ which just executes the block if it was updated;
  #
  # After initialization, a call to +execute_if_updated+ must execute
  # the block only if there was really a change in the filesystem.
  #
  # == Examples
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
  class FileUpdateChecker
    # It accepts two parameters on initialization. The first is an array
    # of files and the second is an optional hash of directories. The hash must
    # have directories as keys and the value is an array of extensions to be
    # watched under that directory.
    #
    # This method must also receive a block that will be called once a path changes.
    #
    # == Implementation details
    #
    # This particular implementation checks for added and updated files,
    # but not removed files. Directories lookup are compiled to a glob for
    # performance. Therefore, while someone can add new files to the +files+
    # array after initialization (and parts of Rails do depend on this feature),
    # adding new directories after initialization is not allowed.
    #
    # Notice that other objects that implements FileUpdateChecker API may
    # not even allow new files to be added after initialization. If this
    # is the case, we recommend freezing the +files+ after initialization to
    # avoid changes that won't make effect.
    def initialize(files, dirs={}, &block)
      @files = files
      @glob  = compile_glob(dirs)
      @block = block
      @updated_at = nil
      @last_update_at = updated_at
    end

    # Check if any of the entries were updated. If so, the updated_at
    # value is cached until the block is executed via +execute+ or +execute_if_updated+
    def updated?
      current_updated_at = updated_at
      if @last_update_at < current_updated_at
        @updated_at = updated_at
        true
      else
        false
      end
    end

    # Executes the given block and updates the counter to latest timestamp.
    def execute
      @last_update_at = updated_at
      @block.call
    ensure
      @updated_at = nil
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

    def updated_at #:nodoc:
      @updated_at || begin
        all = []
        all.concat @files.select { |f| File.exists?(f) }
        all.concat Dir[@glob] if @glob
        all.map { |path| File.mtime(path) }.max || Time.at(0)
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
