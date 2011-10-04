require 'fileutils'

module Sprockets
  class StaticCompiler
    MODES = ['primary', 'digestless']
    class << self
      def assert_valid_configuration(assets, mode)
        unless assets.enabled
          raise "Cannot precompile assets if sprockets is disabled. Please set config.assets.enabled to true"
        end
        
        unless MODES.include?(mode)
          raise "Unknown asset compilation mode: #{mode}. Please use one of #{MODES.join}"
        end
      end

      def configure_assets!(assets,mode)
        assets.digest = false if mode == 'digestless'
        assets.compile = true
        assets.digests = {}
      end

      def compiler_for(assets, env, mode = 'primary')
        assert_valid_configuration(assets, mode)

        # Ensure that action view is loaded and the appropriate
        # sprockets hooks get executed
        _ = ActionView::Base
        
        configure_assets!(assets,mode)

        target = File.join(Rails.public_path, assets.prefix)
        Sprockets::StaticCompiler.new(env, 
                                      target,
                                      assets.precompile,
                                      :manifest_path => assets.manifest,
                                      :digest => assets.digest,
                                      :manifest => (mode == 'primary'))
      end
    end

    attr_accessor :env, :target, :paths

    def initialize(env, target, paths, options = {})
      @env = env
      @target = target
      @paths = paths
      @digest = options.key?(:digest) ? options.delete(:digest) : true
      @manifest = options.key?(:manifest) ? options.delete(:manifest) : true
      @manifest_path = options.delete(:manifest_path) || target
    end

    def compile_generating_manifest
      write_manifest(compile)
    end

    def compile
      manifest = {}
      env.each_logical_path do |logical_path|
        next unless compile_path?(logical_path)
        if asset = env.find_asset(logical_path)
          manifest[logical_path] = write_asset(asset)
        end
      end
      write_manifest(manifest) if @manifest
    end

    def write_manifest(manifest)
      FileUtils.mkdir_p(@manifest_path)
      File.open("#{@manifest_path}/manifest.yml", 'wb') do |f|
        YAML.dump(manifest, f)
      end
    end

    def write_asset(asset)
      path_for(asset).tap do |path|
        filename = File.join(target, path)
        FileUtils.mkdir_p File.dirname(filename)
        asset.write_to(filename)
        asset.write_to("#{filename}.gz") if filename.to_s =~ /\.(css|js)$/
      end
    end

    def compile_path?(logical_path)
      paths.each do |path|
        case path
        when Regexp
          return true if path.match(logical_path)
        when Proc
          return true if path.call(logical_path)
        else
          return true if File.fnmatch(path.to_s, logical_path)
        end
      end
      false
    end

    def path_for(asset)
      @digest ? asset.digest_path : asset.logical_path
    end
  end
end
