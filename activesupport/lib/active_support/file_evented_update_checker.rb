require 'listen'
require 'set'
require 'pathname'

module ActiveSupport
  class FileEventedUpdateChecker
    attr_reader :listener

    def initialize(files, dirs={}, &block)
      @files = files.map {|f| expand_path(f)}.to_set

      @dirs = {}
      dirs.each do |dir, exts|
        @dirs[expand_path(dir)] = Array(exts).map(&:to_s)
      end

      @block = block
      @modified = false

      if (watch_dirs = base_directories).any?
        @listener = Listen.to(*watch_dirs, &method(:changed))
        @listener.start
      end
    end

    def updated?
      @modified
    end

    def execute
      @block.call
    ensure
      @modified = false
    end

    def execute_if_updated
      if updated?
        execute
        true
      end
    end

    private

    def expand_path(fname)
      File.expand_path(fname)
    end

    def changed(modified, added, removed)
      return if updated?

      if (modified + added + removed).any? {|f| watching?(f)}
        @modified = true
      end
    end

    def watching?(file)
      file = expand_path(file)
      return true if @files.member?(file)

      file = Pathname.new(file)
      return false if file.directory?

      ext = file.extname.sub(/\A\./, '')
      dir = file.dirname

      loop do
        if @dirs.fetch(dir.to_path, []).include?(ext)
          break true
        else
          if dir.root? # TODO: find a common parent directory in initialize
            break false
          end
          dir = dir.parent
        end
      end
    end

    # TODO: Better return a list of non-nested directories.
    def base_directories
      [].tap do |bd|
        bd.concat @files.map {|f| existing_parent(File.dirname(f))}
        bd.concat @dirs.keys.map {|dir| existing_parent(dir)}
        bd.compact!
        bd.uniq!
      end
    end

    def existing_parent(dir)
      dir = Pathname.new(File.expand_path(dir))

      loop do
        if dir.directory?
          break dir.to_path
        else
          if dir.root?
            # Edge case in which not even the root exists. For example, Windows
            # paths could have a non-existing drive letter. Since the parent of
            # root is root, we need to break to prevent an infinite loop.
            break
          else
            dir = dir.parent
          end
        end
      end
    end
  end
end
