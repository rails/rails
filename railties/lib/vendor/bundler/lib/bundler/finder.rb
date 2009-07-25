module Bundler
  class Finder
    def initialize(*sources)
      @results = {}
      @index   = Hash.new { |h,k| h[k] = {} }

      sources.each { |source| fetch(source) }
    end

    def resolve(*dependencies)
      resolved = Resolver.resolve(dependencies, self)
      resolved && GemBundle.new(resolved.all_specs)
    end

    def fetch(source)
      deflated = Gem::RemoteFetcher.fetcher.fetch_path("#{source}/Marshal.4.8.Z")
      inflated = Gem.inflate deflated

      append(Marshal.load(inflated), source)
    rescue Gem::RemoteFetcher::FetchError => e
      raise ArgumentError, "#{source} is not a valid source: #{e.message}"
    end

    def append(index, source)
      index.gems.values.each do |spec|
        next unless Gem::Platform.match(spec.platform)
        spec.source = source
        @index[spec.name][spec.version] ||= spec
      end
      self
    end

    def search(dependency)
      @results[dependency.hash] ||= begin
        possibilities = @index[dependency.name].values
        possibilities.select do |spec|
          dependency =~ spec
        end.sort_by {|s| s.version }
      end
    end
  end
end