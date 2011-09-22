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

      RESCUE_ERRORS = [ ArgumentError ] # :nodoc:

      private
      if defined?(Psych) && defined?(Psych::SyntaxError)
        RESCUE_ERRORS << Psych::SyntaxError
      end

      def rows
        return @rows if @rows

        begin
          data = YAML.load(render(IO.read(@file)))
        rescue *RESCUE_ERRORS => error
          raise Fixture::FormatError, "a YAML error occurred parsing #{@file}. Please note that YAML must be consistently indented using spaces. Tabs are not allowed. Please have a look at http://www.yaml.org/faq.html\nThe exact error was:\n  #{error.class}: #{error}", error.backtrace
        end
        @rows = data ? validate(data).to_a : []
      end

      def render(content)
        ERB.new(content).result
      end

      # Validate our unmarshalled data.
      def validate(data)
        unless Hash === data || YAML::Omap === data
          raise Fixture::FormatError, 'fixture is not a hash'
        end

        raise Fixture::FormatError unless data.all? { |name, row| Hash === row }
        data
      end
    end
  end
end
