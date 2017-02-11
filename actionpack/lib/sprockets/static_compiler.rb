require 'fileutils'

module Sprockets
  class StaticCompiler
    attr_accessor :env, :target, :paths

    def initialize(env, target, paths, options = {})
      @env = env
      @target = target
      @paths = paths
      @digest = options.fetch(:digest, true)
      @manifest = options.fetch(:manifest, true)
      @manifest_path = options.delete(:manifest_path) || target

      @current_source_digests = options.fetch(:source_digests, {})
      @current_digests   = options.fetch(:digests,   {})

      @digests = {}
      @source_digests = {}
    end

    def compile
      start_time = Time.now.to_f

      # Run asset compilation
      process_assets

      # Encode all filenames & digests as UTF-8 for Ruby 1.9,
      # otherwise YAML dumps other string encodings as !binary
      if RUBY_VERSION.to_f >= 1.9
        @source_digests = encode_hash_as_utf8 @source_digests
        @digests = encode_hash_as_utf8 @digests
      end

      if @manifest
        write_manifest(@digests, @source_digests)
      end

      # Store digests in Rails config. (Important if non-digest is run after primary)
      config = ::Rails.application.config
      config.assets.digests = @digests
      config.assets.source_digests = @source_digests

      elapsed_time = ((Time.now.to_f - start_time) * 1000).to_i
      env.logger.debug "Processed #{'non-' unless @digest}digest assets in #{elapsed_time}ms"
    end

    # Compiles assets if their source digests haven't changed
    def process_assets
      env.each_logical_path(paths) do |logical_path|
        # Fetch asset without any processing or compression,
        # to calculate a digest of the concatenated source files
        asset = env.find_asset(logical_path, :process => false)

        @source_digests[logical_path] = asset.digest

        # Recompile if digest has changed or compiled digest file is missing
        current_digest_file = @current_digests[logical_path]

        if @source_digests[logical_path] != @current_source_digests[logical_path] ||
           !(current_digest_file && File.exists?("#{@target}/#{current_digest_file}"))

          if asset = env.find_asset(logical_path)
            digest_path = write_asset(asset)
            @digests[asset.logical_path] = digest_path
            @digests[aliased_path_for(asset.logical_path)] = digest_path
          end
        else
          # Set asset file from manifest.yml
          digest_path = @current_digests[logical_path]
          @digests[logical_path] = digest_path
          @digests[aliased_path_for(logical_path)] = digest_path

          env.logger.debug "Not compiling #{logical_path}, sources digest has not changed " <<
                           "(#{@source_digests[logical_path][0...7]})"
        end
      end
    end

    def write_manifest(digests, source_digests)
      FileUtils.mkdir_p(@manifest_path)
      File.open("#{@manifest_path}/manifest.yml", 'wb') do |f|
        YAML.dump(digests, f)
      end
      File.open("#{@manifest_path}/sources_manifest.yml", 'wb') do |f|
        YAML.dump(source_digests, f)
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


    def path_for(asset)
      @digest ? asset.digest_path : asset.logical_path
    end

    def encode_hash_as_utf8(hash)
      Hash[*hash.map {|k,v| [k.encode("UTF-8"), v.encode("UTF-8")] }.flatten]
    end

    def aliased_path_for(logical_path)
      if File.basename(logical_path).start_with?('index')
        logical_path.sub(/\/index([^\/]+)$/, '\1')
      else
        logical_path.sub(/\.([^\/]+)$/, '/index.\1')
      end
    end
  end
end
