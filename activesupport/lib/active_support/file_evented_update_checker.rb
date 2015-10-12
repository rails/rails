require 'listen'

module ActiveSupport
  class FileEventedUpdateChecker
    attr_reader :listener
    def initialize(files, directories={}, &block)
      @files = files.map { |f| File.expand_path(f)}.to_set
      @dirs = Hash.new
      directories.each do |key,value|
        @dirs[File.expand_path(key)] = Array(value) if !Array(value).empty?
      end
      @block = block
      @modified = false
      watch_dirs = base_directories
      @listener = Listen.to(*watch_dirs,&method(:changed)) if !watch_dirs.empty?
      @listener.start if @listener
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
      else
        false
      end
    end

    private

    def watching?(file)
      return true if @files.include?(file)
      cfile = file
      while !cfile.eql? "/"
        cfile = File.expand_path("#{cfile}/..")
        if !@dirs[cfile].nil? and file.end_with?(*(@dirs[cfile].map {|ext| ".#{ext.to_s}"}))
          return true
        end
      end
      false
    end

    def changed(modified, added, removed)
      return if updated?
      if (modified + added + removed).any? { |f| watching? f }
        @modified = true
      end
    end

    def base_directories
      (@files.map { |f| existing_parent(File.expand_path("#{f}/..")) } + @dirs.keys.map {|dir| existing_parent(dir)}).uniq
    end

    def existing_parent(path)
      File.exist?(path) ? path : existing_parent(File.expand_path("#{path}/.."))
    end
  end
end
