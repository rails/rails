require 'erb'
require 'yaml'

module ActiveRecord
  class FixtureSet
    class File # :nodoc:
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
        @raw_rows = nil
        @model_class = nil
      end

      def each(&block)
        rows.each(&block)
      end

      def model_class
        return @model_class if @model_class
        row = raw_rows.find { |fixture_name, _| fixture_name == '_fixture' }
        @model_class = row.last['model_class'] if row
      end

      private
        def rows
          @rows ||= raw_rows.reject { |fixture_name, _| fixture_name == '_fixture' }
        end

        def raw_rows
          return @raw_rows if @raw_rows

          begin
            data = YAML.load(render(IO.read(@file)))
          rescue ArgumentError, Psych::SyntaxError => error
            raise Fixture::FormatError, "a YAML error occurred parsing #{@file}. Please note that YAML must be consistently indented using spaces. Tabs are not allowed. Please have a look at http://www.yaml.org/faq.html\nThe exact error was:\n  #{error.class}: #{error}", error.backtrace
          end
          @raw_rows = data ? validate(data).to_a : []
        end

        def render(content)
          context = ActiveRecord::FixtureSet::RenderContext.create_subclass.new
          ERB.new(content).result(context.get_binding)
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
