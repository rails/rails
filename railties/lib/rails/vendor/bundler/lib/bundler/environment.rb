require "rubygems/source_index"

module Bundler
  class DefaultManifestNotFound < StandardError; end

  class Environment
    attr_reader :filename, :dependencies
    attr_accessor :rubygems, :system_gems, :gem_path, :bindir

    def self.load(gemfile = nil)
      gemfile = gemfile ? Pathname.new(gemfile) : default_manifest_file

      unless gemfile.file?
        raise ManifestFileNotFound, "#{filename.inspect} does not exist"
      end

      new(gemfile)
    end

    def self.default_manifest_file
      current = Pathname.new(Dir.pwd)

      until current.root?
        filename = current.join("Gemfile")
        return filename if filename.exist?
        current = current.parent
      end

      raise DefaultManifestNotFound
    end

    def initialize(filename) #, sources, dependencies, bindir, path, rubygems, system_gems)
      @filename         = filename
      @default_sources  = [GemSource.new(:uri => "http://gems.rubyforge.org")]
      @sources          = []
      @priority_sources = []
      @dependencies     = []
      @rubygems         = true
      @system_gems      = true

      # Evaluate the Gemfile
      builder = Dsl.new(self)
      builder.instance_eval(File.read(filename))
    end

    def install(update = false)
      begin
        tmp_path = filename.dirname.join(".tmp")
        FileUtils.mkdir_p(tmp_path)
        sources.each { |s| s.tmp_path = tmp_path }
        repository.install(gem_dependencies, sources,
          :rubygems    => rubygems,
          :system_gems => system_gems,
          :manifest    => filename,
          :update      => update
        )
      ensure
        FileUtils.rm_rf(tmp_path)
      end
      Bundler.logger.info "Done."
    end

    def setup_environment
      unless system_gems
        ENV["GEM_HOME"] = gem_path
        ENV["GEM_PATH"] = gem_path
      end
      ENV["PATH"]     = "#{bindir}:#{ENV["PATH"]}"
      ENV["RUBYOPT"]  = "-r#{gem_path}/environment #{ENV["RUBYOPT"]}"
    end

    def root
      filename.parent
    end

    def gem_path
      @gem_path ||= root.join("vendor", "gems")
    end

    def bindir
      @bindir ||= root.join("bin")
    end

    def sources
      @priority_sources + @sources + @default_sources
    end

    def add_source(source)
      @sources << source
    end

    def add_priority_source(source)
      @priority_sources << source
    end

    def clear_sources
      @sources.clear
      @default_sources.clear
    end

  private

    def repository
      @repository ||= Repository.new(gem_path, bindir)
    end

    def gem_dependencies
      @gem_dependencies ||= dependencies.map { |d| d.to_gem_dependency }
    end
  end
end
