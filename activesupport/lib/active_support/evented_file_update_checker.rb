require "set"
require "pathname"
require "concurrent/atomic/atomic_boolean"

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
  #     checker = EventedFileUpdateChecker.new(["/tmp/foo"], -> { puts "changed" })
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
      @ph    = PathHelper.new
      @files = files.map { |f| @ph.xpath(f) }.to_set

      @dirs = {}
      dirs.each do |dir, exts|
        @dirs[@ph.xpath(dir)] = Array(exts).map { |ext| @ph.normalize_extension(ext) }
      end

      @block      = block
      @updated    = Concurrent::AtomicBoolean.new(false)
      @lcsp       = @ph.longest_common_subpath(@dirs.keys)
      @pid        = Process.pid
      @boot_mutex = Mutex.new

      if (@dtw = directories_to_watch).any?
        # Loading listen triggers warnings. These are originated by a legit
        # usage of attr_* macros for private attributes, but adds a lot of noise
        # to our test suite. Thus, we lazy load it and disable warnings locally.
        silence_warnings do
          begin
            require "listen"
          rescue LoadError => e
            raise LoadError, "Could not load the 'listen' gem. Add `gem 'listen'` to the development group of your Gemfile", e.backtrace
          end
        end
      end
      boot!
    end

    def updated?
      @boot_mutex.synchronize do
        if @pid != Process.pid
          boot!
          @pid = Process.pid
          @updated.make_true
        end
      end
      @updated.true?
    end

    def execute
      @updated.make_false
      @block.call
    end

    def execute_if_updated
      if updated?
        yield if block_given?
        execute
        true
      end
    end

    private
      def boot!
        Listen.to(*@dtw, &method(:changed)).start
      end

      def changed(modified, added, removed)
        unless updated?
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
            if @dirs.fetch(dir, []).include?(ext)
              break true
            elsif dir == @lcsp || dir.root?
              break false
            end
          end
        end
      end

      def directories_to_watch
        dtw = (@files + @dirs.keys).map { |f| @ph.existing_parent(f) }
        dtw.compact!
        dtw.uniq!

        @ph.filter_out_descendants(dtw)
      end

      class PathHelper
        def xpath(path)
          Pathname.new(path).expand_path
        end

        def normalize_extension(ext)
          ext.to_s.sub(/\A\./, "")
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

        # Returns the deepest existing ascendant, which could be the argument itself.
        def existing_parent(dir)
          dir.ascend do |ascendant|
            break ascendant if ascendant.directory?
          end
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
