require 'listen'
require 'set'
require 'pathname'

module ActiveSupport
  class FileEventedUpdateChecker #:nodoc: all
    def initialize(files, dirs = {}, &block)
      @ph    = PathHelper.new
      @files = files.map { |f| @ph.xpath(f) }.to_set

      @dirs = {}
      dirs.each do |dir, exts|
        @dirs[@ph.xpath(dir)] = Array(exts).map { |ext| @ph.normalize_extension(ext) }
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
          @updated = (modified + added + removed).any? { |f| watching?(f) }
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
      using Module.new {
        refine Pathname do
          def ascendant_of?(other)
            if self != other && other.to_s.start_with?(to_s)
              # On Windows each_filename does not include the drive letter,
              # but the test above already detects if they differ.
              parts = each_filename.to_a
              other_parts = other.each_filename.to_a

              other_parts[0, parts.length] == parts
            end
          end
        end
      }

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

        lcsp = Pathname.new(paths[0])

        paths[1..-1].each do |path|
          until lcsp.ascendant_of?(path)
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
            dir.ascendant_of?(possible_descendant) && descendants << possible_descendant
          end
        end

        # Array#- preserves order.
        dirs - descendants
      end
    end
  end
end
