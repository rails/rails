module Bundler
  class Repository
    class Directory
      attr_reader :path, :bindir

      def initialize(path, bindir)
        @path   = path
        @bindir = bindir

        FileUtils.mkdir_p(path.to_s)
      end

      def source_index
        index = Gem::SourceIndex.from_gems_in(@path.join("specifications"))
        index.each { |n, spec| spec.loaded_from = @path.join("specifications", "#{spec.full_name}.gemspec") }
        index
      end

      def gems
        source_index.gems.values
      end

      def add_spec(spec)
        destination = path.join('specifications')
        destination.mkdir unless destination.exist?

        File.open(destination.join("#{spec.full_name}.gemspec"), 'w') do |f|
          f.puts spec.to_ruby
        end
      end

      def download_path_for
        @path.join("dirs")
      end

      # Checks whether a gem is installed
      def expand(options)
        # raise NotImplementedError
      end

      def cleanup(gems)
        # raise NotImplementedError
      end
    end
  end
end