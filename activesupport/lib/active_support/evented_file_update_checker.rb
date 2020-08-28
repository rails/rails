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
        @files = files.map { |file| Pathname(file).expand_path }.to_set

        @dirs = dirs.each_with_object({}) do |(dir, exts), hash|
          hash[Pathname(dir).expand_path] = Array(exts).map { |ext| ext.to_s.sub(/\A\.?/, ".") }.to_set
        end

        @common_path = common_path(@dirs.keys)

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
        file = Pathname(file)

        if @files.member?(file)
          true
        elsif file.directory?
          false
        else
          ext = file.extname

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
        dtw = @dirs.keys | @files.map(&:dirname)
        accounted_for = dtw.to_set + Gem.path.map { |path| Pathname(path) }
        dtw.reject { |dir| dir.ascend.drop(1).any? { |parent| accounted_for.include?(parent) } }
      end

      def common_path(paths)
        paths.map { |path| path.ascend.to_a }.reduce(&:&)&.first
      end
    end
  end
end
