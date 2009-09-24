module Bundler
  # Finder behaves like a rubygems source index in that it responds
  # to #search. It also resolves a list of dependencies finding the
  # best possible configuration of gems that satisifes all requirements
  # without causing any gem activation errors.
  class Finder

    # Takes an array of gem sources and fetches the full index of
    # gems from each one. It then combines the indexes together keeping
    # track of the original source so that any resolved gem can be
    # fetched from the correct source.
    #
    # ==== Parameters
    # *sources<String>:: URI pointing to the gem repository
    def initialize(*sources)
      @cache   = {}
      @index   = {}
      @sources = sources
    end

    # Searches for a gem that matches the dependency
    #
    # ==== Parameters
    # dependency<Gem::Dependency>:: The gem dependency to search for
    #
    # ==== Returns
    # [Gem::Specification]:: A collection of gem specifications
    #   matching the search
    def search(dependency)
      @cache[dependency.hash] ||= begin
        find_by_name(dependency.name).select do |spec|
          dependency =~ spec
        end.sort_by {|s| s.version }
      end
    end

  private

    def find_by_name(name)
      matches = @index[name] ||= begin
        versions = {}
        @sources.reverse_each do |source|
          versions.merge! source.specs[name] || {}
        end
        versions
      end
      matches.values
    end

  end
end