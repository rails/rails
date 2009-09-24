module Bundler
  class Repository
    class Gems
      attr_reader :path, :bindir

      def initialize(path, bindir)
        @path   = path
        @bindir = bindir
      end

      # Returns the source index for all gems installed in the
      # repository
      def source_index
        index = Gem::SourceIndex.from_gems_in(@path.join("specifications"))
        index.each { |n, spec| spec.loaded_from = @path.join("specifications", "#{spec.full_name}.gemspec") }
        index
      end

      def gems
        source_index.gems.values
      end

      # Checks whether a gem is installed
      def expand(options)
        cached_gems.each do |name, version|
          unless installed?(name, version)
            install_cached_gem(name, version, options)
          end
        end
      end

      def cleanup(gems)
        glob = gems.map { |g| g.full_name }.join(',')
        base = path.join("{cache,specifications,gems}")

        (Dir[base.join("*")] - Dir[base.join("{#{glob}}{.gemspec,.gem,}")]).each do |file|
          if File.basename(file) =~ /\.gem$/
            name = File.basename(file, '.gem')
            Bundler.logger.info "Deleting gem: #{name}"
          end
          FileUtils.rm_rf(file)
        end
      end

      def add_spec(spec)
        raise NotImplementedError
      end

      def download_path_for
        path
      end

    private

      def cache_path
        @path.join("cache")
      end

      def cache_files
        Dir[cache_path.join("*.gem")]
      end

      def cached_gems
        cache_files.map do |f|
          full_name = File.basename(f).gsub(/\.gem$/, '')
          full_name.split(/-(?=[^-]+$)/)
        end
      end

      def spec_path
        @path.join("specifications")
      end

      def spec_files
        Dir[spec_path.join("*.gemspec")]
      end

      def gem_path
        @path.join("gems")
      end

      def gem_paths
        Dir[gem_path.join("*")]
      end

      def installed?(name, version)
        spec_files.any? { |g| File.basename(g) == "#{name}-#{version}.gemspec" } &&
          gem_paths.any? { |g| File.basename(g) == "#{name}-#{version}" }
      end

      def install_cached_gem(name, version, options = {})
        cached_gem = cache_path.join("#{name}-#{version}.gem")
        # TODO: Add a warning if cached_gem is not a file
        if cached_gem.file?
          Bundler.logger.info "Installing #{name}-#{version}.gem"
          installer = Gem::Installer.new(cached_gem.to_s, options.merge(
            :install_dir         => @path,
            :ignore_dependencies => true,
            :env_shebang         => true,
            :wrappers            => true,
            :bin_dir             => @bindir
          ))
          installer.install
        end
      end
    end
  end
end