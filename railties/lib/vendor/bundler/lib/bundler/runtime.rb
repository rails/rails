module Bundler
  class ManifestBuilder

    attr_reader :sources

    def self.build(path, string)
      builder = new(path)
      builder.instance_eval(string)
      builder.to_manifest
    end

    def self.load(path, file)
      string = File.read(file)
      build(path, string)
    end

    def initialize(path)
      @path         = path
      @sources      = %w(http://gems.rubyforge.org)
      @dependencies = []
    end

    def to_manifest
      Manifest.new(@sources, @dependencies, @path)
    end

    def source(source)
      @sources << source
    end

    def gem(name, *args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      version = args.last

      @dependencies << Dependency.new(name, options.merge(:version => version))
    end

  end
end