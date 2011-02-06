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

    def watch(path, &block)
      return watch_regex(path, &block) if path.is_a?(Regexp)
      raise "Paths must be regular expressions. #{path.inspect} is a #{path.class}"
    end

    def watch_regex(regex, &block)
      @regex_matchers[regex] = block
    end

    def trigger(files)
      trigger_files = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }

      files.each do |file, state|
        @regex_matchers.each do |regex, block|
          trigger_files[block][state] << file if file =~ regex
        end
      end

      trigger_files.each do |block, payload|
        block.call payload
      end
    end
  end
end
