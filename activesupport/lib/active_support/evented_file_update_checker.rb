# frozen_string_literal: true

require "set"
require "pathname"
require "concurrent/atomic/atomic_boolean"
require "listen"

module ActiveSupport
  # Allows you to "listen" to changes in a file system.
  # The evented file updater does not hit disk when checking for updates
  # instead it uses platform specific file system events to trigger a change
  # in state.
  #
  # The file checker takes an array of files to watch or a hash specifying directories
  # and file extensions to watch. It also takes a block that is called when
  # EventedFileUpdateChecker#execute is run or when EventedFileUpdateChecker#execute_if_updated
  # is run and there have been changes to the file system.
  #
  # Note: Forking will cause the first call to `updated?` to return `true`.
  #
  # Example:
  #
  #     checker = ActiveSupport::EventedFileUpdateChecker.new(["/tmp/foo"]) { puts "changed" }
  #     checker.updated?
  #     # => false
  #     checker.execute_if_updated
  #     # => nil
  #
  #     FileUtils.touch("/tmp/foo")
  #
  #     checker.updated?
  #     # => true
  #     checker.execute_if_updated
  #     # => "changed"
  #
  class EventedFileUpdateChecker #:nodoc: all
    def initialize(files, dirs = {}, &block)
      unless block
        raise ArgumentError, "A block is required to initialize an EventedFileUpdateChecker"
      end

      @block = block
      @pid = Process.pid
      @core = Core.new(files, dirs)
      ObjectSpace.define_finalizer(self, @core.finalizer)
    end

    def updated?
      @core.mutex.synchronize do
        if @pid != Process.pid
          @core.start
          @pid = Process.pid
          @core.updated.make_true
        end
      end

      if @core.restart?
        @core.thread_safely(&:restart)
        @core.updated.make_true
      end

      @core.updated.true?
    end

    def execute
      @core.updated.make_false
      @block.call
    end

    def execute_if_updated
      if updated?
        yield if block_given?
        execute
        true
      end
    end

    class Core
      attr_reader :updated, :mutex

      def initialize(files, dirs)
        @ph = PathHelper.new
        @files = files.map { |file| @ph.xpath(file) }.to_set

        @dirs = dirs.each_with_object({}) do |(dir, exts), hash|
          hash[@ph.xpath(dir)] = Array(exts).map { |ext| @ph.normalize_extension(ext) }.to_set
        end

        @common_path = @ph.longest_common_subpath(@dirs.keys)

        @dtw = directories_to_watch
        @missing = []

        @updated = Concurrent::AtomicBoolean.new(false)
        @mutex = Mutex.new

        start
      end

      def finalizer
        proc { stop }
      end

      def thread_safely
        @mutex.synchronize do
          yield self
        end
      end

      def start
        normalize_dirs!
        @dtw, @missing = [*@dtw, *@missing].partition(&:exist?)
        @listener = @dtw.any? ? Listen.to(*@dtw, &method(:changed)) : nil
        @listener&.start
      end

      def stop
        @listener&.stop
      end

      def restart
        stop
        start
      end

      def restart?
        @missing.any?(&:exist?)
      end

      def normalize_dirs!
        @dirs.transform_keys! do |dir|
          dir.exist? ? dir.realpath : dir
        end
      end

      def changed(modified, added, removed)
        unless @updated.true?
          @updated.make_true if (modified + added + removed).any? { |f| watching?(f) }
        end
      end

      def watching?(file)
        file = @ph.xpath(file)

        if @files.member?(file)
          true
        elsif file.directory?
          false
        else
          ext = @ph.normalize_extension(file.extname)

          file.dirname.ascend do |dir|
            matching = @dirs[dir]

            if matching && (matching.empty? || matching.include?(ext))
              break true
            elsif dir == @common_path || dir.root?
              break false
            end
          end
        end
      end

      def directories_to_watch
        dtw = @files.map(&:dirname) + @dirs.keys
        dtw.compact!
        dtw.uniq!

        normalized_gem_paths = Gem.path.map { |path| File.join path, "" }
        dtw = dtw.reject do |path|
          normalized_gem_paths.any? { |gem_path| path.to_path.start_with?(gem_path) }
        end

        @ph.filter_out_descendants(dtw)
      end
    end

      class PathHelper
        def xpath(path)
          Pathname.new(path).expand_path
        end

        def normalize_extension(ext)
          ext.to_s.delete_prefix(".")
        end

        # Given a collection of Pathname objects returns the longest subpath
        # common to all of them, or +nil+ if there is none.
        def longest_common_subpath(paths)
          return if paths.empty?

          lcsp = Pathname.new(paths[0])

          paths[1..-1].each do |path|
            until ascendant_of?(lcsp, path)
              if lcsp.root?
                # If we get here a root directory is not an ascendant of path.
                # This may happen if there are paths in different drives on
                # Windows.
                return
              else
                lcsp = lcsp.parent
              end
            end
          end

          lcsp
        end

        # Filters out directories which are descendants of others in the collection (stable).
        def filter_out_descendants(dirs)
          return dirs if dirs.length < 2

          dirs_sorted_by_nparts = dirs.sort_by { |dir| dir.each_filename.to_a.length }
          descendants = []

          until dirs_sorted_by_nparts.empty?
            dir = dirs_sorted_by_nparts.shift

            dirs_sorted_by_nparts.reject! do |possible_descendant|
              ascendant_of?(dir, possible_descendant) && descendants << possible_descendant
            end
          end

          # Array#- preserves order.
          dirs - descendants
        end

        private
          def ascendant_of?(base, other)
            base != other && other.ascend do |ascendant|
              break true if base == ascendant
            end
          end
      end
  end
end
