module Bundler
  # Represents a source of rubygems. Initially, this is only gem repositories, but
  # eventually, this will be git, svn, HTTP
  class Source
    attr_accessor :tmp_path
  end

  class GemSource < Source
    attr_reader :uri

    def initialize(options)
      @uri = options[:uri]
      @uri = URI.parse(@uri) unless @uri.is_a?(URI)
      raise ArgumentError, "The source must be an absolute URI" unless @uri.absolute?
    end

    def gems
      @specs ||= fetch_specs
    end

    def ==(other)
      uri == other.uri
    end

    def to_s
      @uri.to_s
    end

    class RubygemsRetardation < StandardError; end

    def download(spec, repository)
      Bundler.logger.info "Downloading #{spec.full_name}.gem"

      destination = repository.download_path_for(:gem)

      unless destination.writable?
        raise RubygemsRetardation
      end

      Gem::RemoteFetcher.fetcher.download(spec, uri, repository.download_path_for(:gem))
    end

  private

    def fetch_specs
      Bundler.logger.info "Updating source: #{to_s}"

      deflated = Gem::RemoteFetcher.fetcher.fetch_path("#{uri}/Marshal.4.8.Z")
      inflated = Gem.inflate deflated

      index = Marshal.load(inflated)
      index.gems
    rescue Gem::RemoteFetcher::FetchError => e
      raise ArgumentError, "#{to_s} is not a valid source: #{e.message}"
    end
  end

  class DirectorySource < Source
    def initialize(options)
      @name          = options[:name]
      @version       = options[:version]
      @location      = options[:location]
      @require_paths = options[:require_paths] || %w(lib)
    end

    def gems
      @gems ||= begin
        specs = {}

        # Find any gemspec files in the directory and load those specs
        Dir[@location.join('**', '*.gemspec')].each do |file|
          path = Pathname.new(file).relative_path_from(@location).dirname
          spec = eval(File.read(file))
          spec.require_paths.map! { |p| path.join(p) }
          specs[spec.full_name] = spec
        end

        # If a gemspec for the dependency was not found, add it to the list
        if specs.keys.grep(/^#{Regexp.escape(@name)}/).empty?
          case
          when @version.nil?
            raise ArgumentError, "If you use :at, you must specify the gem" \
              "and version you wish to stand in for"
          when !Gem::Version.correct?(@version)
            raise ArgumentError, "If you use :at, you must specify a gem and" \
              "version. You specified #{@version} for the version"
          end

          default = Gem::Specification.new do |s|
            s.name = @name
            s.version = Gem::Version.new(@version) if @version
          end
          specs[default.full_name] = default
        end

        specs
      end
    end

    def ==(other)
      # TMP HAX
      other.is_a?(DirectorySource)
    end

    def to_s
      "#{@name} (#{@version}) Located at: '#{@location}'"
    end

    def download(spec, repository)
      spec.require_paths.map! { |p| File.join(@location, p) }
      repository.add_spec(:directory, spec)
    end
  end

  class GitSource < DirectorySource
    def initialize(options)
      super
      @uri = options[:uri]
      @ref = options[:ref]
      @branch = options[:branch]
    end

    def gems
      FileUtils.mkdir_p(tmp_path.join("gitz"))

      # TMP HAX to get the *.gemspec reading to work
      @location = tmp_path.join("gitz", @name)

      Bundler.logger.info "Cloning git repository at: #{@uri}"
      `git clone #{@uri} #{@location} --no-hardlinks`

      if @ref
        Dir.chdir(@location) { `git checkout #{@ref}` }
      elsif @branch && @branch != "master"
        Dir.chdir(@location) { `git checkout origin/#{@branch}` }
      end
      super
    end

    def download(spec, repository)
      dest = repository.download_path_for(:directory).join(@name)
      spec.require_paths.map! { |p| File.join(dest, p) }
      repository.add_spec(:directory, spec)
      if spec.name == @name
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.mv(tmp_path.join("gitz", spec.name), dest)
      end
    end
  end
end