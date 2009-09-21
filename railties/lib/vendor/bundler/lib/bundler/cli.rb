require "optparse"

module Bundler
  class CLI
    def self.run(command, options = {})
      new(options).run(command)
    rescue DefaultManifestNotFound => e
      Bundler.logger.error "Could not find a Gemfile to use"
      exit 2
    rescue InvalidEnvironmentName => e
      Bundler.logger.error "Gemfile error: #{e.message}"
      exit
    rescue InvalidRepository => e
      Bundler.logger.error e.message
      exit
    rescue VersionConflict => e
      Bundler.logger.error e.message
      exit
    rescue GemNotFound => e
      Bundler.logger.error e.message
      exit
    end

    def initialize(options)
      @options = options
      @manifest = Bundler::Environment.load(@options[:manifest])
    end

    def bundle
      @manifest.install(@options[:update])
    end

    def exec
      @manifest.setup_environment
      # w0t?
      super(*@options[:args])
    end

    def run(command)
      send(command)
    end

  end
end
