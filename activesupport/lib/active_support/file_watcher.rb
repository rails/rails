module ActiveSupport
  class FileWatcher
    class Backend
      def initialize(path, watcher)
        @watcher = watcher
        @path    = path
      end

      def trigger(files)
        @watcher.trigger(files)
      end
    end

    def initialize
      @regex_matchers = {}
    end

    def watch_regex(regex, &block)
      @regex_matchers[regex] = block
    end
    alias :watch :watch_regex

    def trigger(files)
      trigger_files = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }

      files.each do |file, state|
        @regex_matchers.each do |regex, block|
          trigger_files[block][state] << file if regex === file
        end
      end

      trigger_files.each do |block, payload|
        block.call payload
      end
    end
  end
end
