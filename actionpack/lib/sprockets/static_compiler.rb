require 'fileutils'

module Sprockets
  class StaticCompiler
    attr_accessor :env, :target, :paths

    def initialize(env, target, paths, options = {})
      @env = env
      @target = target
      @paths = paths
      @digest = options.key?(:digest) ? options.delete(:digest) : true
      @manifest = options.key?(:manifest) ? options.delete(:manifest) : true
      @manifest_path = options.delete(:manifest_path) || target
    end

    def compile
      manifest = {}
      env.each_logical_path do |logical_path|
        if File.basename(logical_path)[/[^\.]+/, 0] == 'index'
          logical_path.sub!(/\/index\./, '.')
        end
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
