begin
  require 'psych'
rescue LoadError
end

require 'erb'
require 'yaml'

module ActiveRecord
  class Fixtures
    class File
      include Enumerable

      ##
      # Open a fixture file named +file+.  When called with a block, the block
      # is called with the filehandle and the filehandle is automatically closed
      # when the block finishes.
      def self.open(file)
        x = new file
        block_given? ? yield(x) : x
      end

      def initialize(file)
        @file = file
        @rows = nil
      end

      def each(&block)
        rows.each(&block)
      end

      private
      def rows
        return @rows if @rows
        @rows = YAML.load(render(IO.read(@file))).to_a
      end

      def render(content)
        ERB.new(content).result
      end
    end
  end
end
