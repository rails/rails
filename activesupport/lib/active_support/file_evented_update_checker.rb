require 'listen'
require 'set'
require 'pathname'

module ActiveSupport
  class FileEventedUpdateChecker #:nodoc: all
    def initialize(files, dirs={}, &block)
      @ph    = PathHelper.new
      @files = files.map {|f| @ph.xpath(f)}.to_set

      @dirs = {}
      dirs.each do |dir, exts|
        @dirs[@ph.xpath(dir)] = Array(exts).map {|ext| @ph.normalize_extension(ext)}
      end

      @block   = block
      @updated = false
      @lcsp    = @ph.longest_common_subpath(@dirs.keys)

      if (dtw = directories_to_watch).any?
        Listen.to(*dtw, &method(:changed)).start
      end
    end

    def updated?
      @updated
    end

    def execute
      @block.call
    ensure
      @updated = false
    end

    def execute_if_updated
      if updated?
        execute
        true
      end
    end

    private

    def changed(modified, added, removed)
      unless updated?
        @updated = (modified + added + removed).any? {|f| watching?(f)}
      end
    end

    def watching?(file)
      file = @ph.xpath(file)

      return true  if @files.member?(file)
      return false if file.directory?

      ext = @ph.normalize_extension(file.extname)
      dir = file.dirname

      loop do
        if @dirs.fetch(dir, []).include?(ext)
          break true
        else
          if @lcsp
            break false if dir == @lcsp
          else
            break false if dir.root?
          end

          dir = dir.parent
        end
      end
    end

    def directories_to_watch
      bd = []

      bd.concat @files.map {|f| @ph.existing_parent(f.dirname)}
      bd.concat @dirs.keys.map {|dir| @ph.existing_parent(dir)}
      bd.compact!
      bd.uniq!

      @ph.filter_out_descendants(bd)
    end

    class PathHelper
      def xpath(path)
        Pathname.new(path).expand_path
      end

      def normalize_extension(ext)
        ext.to_s.sub(/\A\./, '')
      end

      # Given a collection of Pathname objects returns the longest subpath
      # common to all of them, or +nil+ if there is none.
      def longest_common_subpath(paths)
        return if paths.empty?

        csp = Pathname.new(paths[0])

        paths[1..-1].each do |path|
          loop do
            break if path.ascend do |ascendant|
              break true if ascendant == csp
            end

            if csp.root?
              # A root directory is not an ascendant of path. This may happen
              # if there are paths in different drives on Windows.
              return
            else
              csp = csp.parent
            end
          end
        end

        csp
      end

      # Returns the deepest existing ascendant, which could be the argument itself.
      def existing_parent(dir)
        loop do
          if dir.directory?
            break dir
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

      # Filters out directories which are descendants of others in the collection (stable).
      def filter_out_descendants(directories)
        return directories if directories.length < 2

        sorted      = directories.sort_by {|dir| dir.each_filename.to_a.length}
        descendants = []

        until sorted.empty?
          directory = sorted.shift

          sorted.each do |candidate_to_descendant|
            if candidate_to_descendant.to_path.start_with?(directory.to_path)
              dparts = directory.each_filename.to_a
              cparts = candidate_to_descendant.each_filename.to_a

              if cparts[0, dparts.length] == dparts
                descendants << candidate_to_descendant
              end
            end
          end
        end

        directories - descendants
      end
    end
  end
end
