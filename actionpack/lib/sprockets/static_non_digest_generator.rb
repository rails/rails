require 'fileutils'

module Sprockets
  class StaticNonDigestGenerator

    DIGEST_REGEX = /-([0-9a-f]{32})\./

    attr_accessor :env, :target, :paths

    def initialize(env, target, paths, options = {})
      @env = env
      @target = target
      @paths = paths
      @digests = options.fetch(:digests, {})

      # Parse digests from digests hash
      @asset_digests = Hash[*@digests.map {|file, digest_file|
        [file, digest_file[DIGEST_REGEX, 1]]
      }.flatten]
    end


    # Generate non-digest assets by making a copy of the digest asset,
    # with digests stripped from js and css. The new files are also gzipped.
    # Other assets are copied verbatim.
    def generate
      start_time = Time.now.to_f

      env.each_logical_path(paths) do |logical_path|
        digest_path      = @digests[logical_path]
        abs_digest_path  = "#{@target}/#{digest_path}"
        abs_logical_path = "#{@target}/#{logical_path}"

        mtime = File.mtime(abs_digest_path)

        # Remove known digests from css & js
        if abs_digest_path.match(/\.(?:js|css)$/)
          asset_body = File.read(abs_digest_path)

          # Find all hashes in the asset body with a leading '-'
          asset_body.gsub!(DIGEST_REGEX) do |match|
            # Only remove if known digest
            $1.in?(@asset_digests.values) ? '.' : match
          end

          # Write non-digest file
          File.open abs_logical_path, 'w' do |f|
            f.write asset_body
          end
          # Set modification and access times
          File.utime(File.atime(abs_digest_path), mtime, abs_logical_path)

          # Also write gzipped asset
          File.open("#{abs_logical_path}.gz", 'wb') do |f|
            gz = Zlib::GzipWriter.new(f, Zlib::BEST_COMPRESSION)
            gz.mtime = mtime.to_i
            gz.write asset_body
            gz.close
          end

          env.logger.debug "Stripped digests, copied to #{logical_path}, and created gzipped asset"

        else
          # Otherwise, treat file as binary and copy it.
          # Ignore paths that have no digests, such as READMEs
          unless abs_digest_path == abs_logical_path
            FileUtils.cp_r abs_digest_path, abs_logical_path, :remove_destination => true
            env.logger.debug "Copied binary asset to #{logical_path}"

            # Copy gzipped asset if exists
            if File.exist? "#{abs_digest_path}.gz"
              FileUtils.cp_r "#{abs_digest_path}.gz", "#{abs_logical_path}.gz", :remove_destination => true
              env.logger.debug "Copied gzipped asset to #{logical_path}.gz"
            end
          end
        end
      end


      elapsed_time = ((Time.now.to_f - start_time) * 1000).to_i
      env.logger.debug "Generated non-digest assets in #{elapsed_time}ms"
    end

    private

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
  end
end