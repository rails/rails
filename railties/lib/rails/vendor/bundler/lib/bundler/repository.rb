require "bundler/repository/gem_repository"
require "bundler/repository/directory_repository"

module Bundler
  class InvalidRepository < StandardError ; end

  class Repository
    attr_reader :path

    def initialize(path, bindir)
      FileUtils.mkdir_p(path)

      @path   = Pathname.new(path)
      @bindir = Pathname.new(bindir)

      @repos = {
        :gem       => Gems.new(@path, @bindir),
        :directory => Directory.new(@path.join("dirs"), @bindir)
      }
    end

    def install(dependencies, sources, options = {})
      if options[:update] || !satisfies?(dependencies)
        fetch(dependencies, sources)
        expand(options)
      else
        # Remove any gems that are still around if the Gemfile changed without
        # requiring new gems to be download (e.g. a line in the Gemfile was
        # removed)
        cleanup(Resolver.resolve(dependencies, [source_index]))
      end
      configure(options)
      sync
    end

    def gems
      gems = []
      each_repo do |repo|
        gems.concat repo.gems
      end
      gems
    end

    def satisfies?(dependencies)
      index = source_index
      dependencies.all? { |dep| index.search(dep).size > 0 }
    end

    def source_index
      index = Gem::SourceIndex.new

      each_repo do |repo|
        index.gems.merge!(repo.source_index.gems)
      end

      index
    end

    def add_spec(type, spec)
      @repos[type].add_spec(spec)
    end

    def download_path_for(type)
      @repos[type].download_path_for
    end

  private

    def cleanup(bundle)
      each_repo do |repo|
        repo.cleanup(bundle)
      end
    end

    def each_repo
      @repos.each do |k, repo|
        yield repo
      end
    end

    def fetch(dependencies, sources)
      bundle = Resolver.resolve(dependencies, sources)
      # Cleanup here to remove any gems that could cause problem in the expansion
      # phase
      #
      # TODO: Try to avoid double cleanup
      cleanup(bundle)
      bundle.download(self)
    end

    def sync
      glob = gems.map { |g| g.executables }.flatten.join(',')

      (Dir[@bindir.join("*")] - Dir[@bindir.join("{#{glob}}")]).each do |file|
        Bundler.logger.info "Deleting bin file: #{File.basename(file)}"
        FileUtils.rm_rf(file)
      end
    end

    def expand(options)
      each_repo do |repo|
        repo.expand(options)
      end
    end

    def configure(options)
      generate_environment(options)
    end

    def generate_environment(options)
      FileUtils.mkdir_p(path)

      specs      = gems
      load_paths = load_paths_for_specs(specs)
      bindir     = @bindir.relative_path_from(path).to_s
      filename   = options[:manifest].relative_path_from(path).to_s
      spec_files = specs.inject({}) do |hash, spec|
        relative = spec.loaded_from.relative_path_from(@path).to_s
        hash.merge!(spec.name => relative)
      end

      File.open(path.join("environment.rb"), "w") do |file|
        template = File.read(File.join(File.dirname(__FILE__), "templates", "environment.erb"))
        erb = ERB.new(template, nil, '-')
        file.puts erb.result(binding)
      end
    end

    def load_paths_for_specs(specs)
      load_paths = []
      specs.each do |spec|
        gem_path = Pathname.new(spec.full_gem_path)
        if spec.bindir
          load_paths << gem_path.join(spec.bindir).relative_path_from(@path).to_s
        end
        spec.require_paths.each do |path|
          load_paths << gem_path.join(path).relative_path_from(@path).to_s
        end
      end
      load_paths
    end

    def require_code(file, dep)
      constraint = case
      when dep.only   then %{ if #{dep.only.inspect}.include?(env)}
      when dep.except then %{ unless #{dep.except.inspect}.include?(env)}
      end
      "require #{file.inspect}#{constraint}"
    end
  end
end