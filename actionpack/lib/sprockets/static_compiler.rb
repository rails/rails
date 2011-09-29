require 'fileutils'

module Sprockets
  class StaticCompiler
    attr_accessor :env, :target, :digest, :digest_exclusions

    def initialize(env, target, options = {})
      @env = env
      @target = target
      @digest = options.key?(:digest) ? options[:digest] : true
      @digest_exclusions = options.key?(:digest_exclusions) ? Array(options[:digest_exclusions]) : []
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
      asset_path = digest_asset?(asset) ? asset.digest_path : asset.logical_path
      filename = File.join(target, asset_path)
      FileUtils.mkdir_p File.dirname(filename)
      asset.write_to(filename)
      asset.write_to("#{filename}.gz") if filename.to_s =~ /\.(css|js)$/
      asset_path
    end

    def precompile_path?(logical_path, paths)
      paths.any? { |path| match_path?(path, logical_path) }
    end

    def digest_asset?(asset)
      digest && digest_exclusions.none? { |path| match_path?(path, asset.logical_path) }
    end

  private
    def match_path?(matcher, path)
      if matcher.is_a?(Regexp)
        matcher.match(path)
      elsif matcher.is_a?(Proc)
        matcher.call(path)
      else
        File.fnmatch(matcher.to_s, path)
      end
    end
  end
end
