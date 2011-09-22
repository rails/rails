require 'fileutils'
require 'pathname'

module Sprockets
  class StaticCompiler
    attr_accessor :env, :target, :digest

    def initialize(env, target, options = {})
      @env = env
      @target = target
      @digest = options.key?(:digest) ? options.delete(:digest) : true
    end

    def precompile(paths)
      Rails.application.config.assets.digest = digest
      manifest = {}

      env.each_logical_path do |logical_path|
        next unless precompile_path?(logical_path, paths)
        if asset = env.find_asset(logical_path)
          manifest[logical_path] = compile(asset)
        end
      end
      manifest
    end

    def compile(asset)
      asset_path = digest_asset(asset)
      filename = target.join(asset_path)
      FileUtils.mkdir_p filename.dirname
      asset.write_to(filename)
      asset.write_to("#{filename}.gz") if filename.to_s =~ /\.(css|js)$/
      asset_path
    end

    def precompile_path?(logical_path, paths)
      paths.each do |path|
        if path.is_a?(Regexp)
          return true if path.match(logical_path)
        elsif path.is_a?(Proc)
          return true if path.call(logical_path)
        else
          return true if File.fnmatch(path.to_s, logical_path)
        end
      end
      false
    end

    def digest_asset(asset)
      digest ? asset.digest_path : asset.logical_path
    end
  end
end
