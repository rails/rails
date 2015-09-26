require 'listen'

module ActiveSupport
  class FileEventedUpdateChecker
    attr_reader :listener

    def initialize(files, directories = {}, &block)
      @files = files.map { |f| File.expand_path(f) }.to_set
      @dirs = Hash.new
      directories.each do |key,value|
        @dirs[File.expand_path(key)] = Array(value) if !Array(value).empty?
      end
      @block = block
      @modified = false
      # Listeners for files.
      begin
        @files.each do |file|
          @listener = Listen.to(File.expand_path("#{file}/.."),&method(:changed))
          @listener.only(Regexp.new("#{Regexp.quote(File.basename(file))}$"))
          @listener.start if @listener
        end
      rescue
      end
      #listeners for directories
      begin
        @dirs.each do |key,value|
          @listener = Listen.to(key,&method(:changed))
          @listener.only(Regexp.new("\\.(?:#{value.join('|')})$")) if !value.empty?
          @listener.start if @listener
        end
      rescue
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
      else
        false
      end
    end

    private

    def changed(modified, added, removed)
      return if updated?
      @modified = true
    end
  end
end
