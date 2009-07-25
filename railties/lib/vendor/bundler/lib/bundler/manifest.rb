require "rubygems/source_index"
require "pathname"

module Bundler
  class VersionConflict < StandardError; end

  class Manifest
    attr_reader :sources, :dependencies, :path

    def initialize(sources, dependencies, path)
      sources.map! {|s| s.is_a?(URI) ? s : URI.parse(s) }
      @sources, @dependencies, @path = sources, dependencies, Pathname.new(path)
    end

    def fetch
      return if all_gems_installed?

      finder = Finder.new(*sources)
      unless bundle = finder.resolve(*gem_dependencies)
        gems = @dependencies.map {|d| "  #{d.to_s}" }.join("\n")
        raise VersionConflict, "No compatible versions could be found for:\n#{gems}"
      end

      bundle.download(@path)
    end

    def install(options = {})
      fetch
      installer = Installer.new(@path)
      installer.install # options come here
      create_load_paths_files(File.join(@path, "environments"))
      create_fake_rubygems(File.join(@path, "environments"))
    end

    def activate(environment = "default")
      require File.join(@path, "environments", "#{environment}.rb")
    end

    def require_all
      dependencies.each do |dep|
        dep.require_as.each {|file| require file }
      end
    end

    def gems_for(environment)
      deps     = dependencies.select { |d| d.in?(environment) }
      deps.map! { |d| d.to_gem_dependency }
      index    = Gem::SourceIndex.from_gems_in(File.join(@path, "specifications"))
      Resolver.resolve(deps, index).all_specs
    end

    def environments
      envs = dependencies.map {|dep| Array(dep.only) + Array(dep.except) }.flatten
      envs << "default"
    end

  private

    def gem_dependencies
      @gem_dependencies ||= dependencies.map { |d| d.to_gem_dependency }
    end

    def all_gems_installed?
      gem_versions = {}

      Dir[File.join(@path, "cache", "*.gem")].each do |file|
        file =~ /\/([^\/]+)-([\d\.]+)\.gem$/
        name, version = $1, $2
        gem_versions[name] = Gem::Version.new(version)
      end

      gem_dependencies.all? do |dep|
        gem_versions[dep.name] &&
        dep.version_requirements.satisfied_by?(gem_versions[dep.name])
      end
    end

    def create_load_paths_files(path)
      FileUtils.mkdir_p(path)
      environments.each do |environment|
        gem_specs = gems_for(environment)
        File.open(File.join(path, "#{environment}.rb"), "w") do |file|
          file.puts <<-RUBY_EVAL
            module Bundler
              def self.rubygems_required
                #{create_gem_stubs(path, gem_specs)}
              end
            end
          RUBY_EVAL
          file.puts "$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))"
          load_paths_for_specs(gem_specs).each do |load_path|
            file.puts "$LOAD_PATH.unshift #{load_path.inspect}"
          end
        end
      end
    end

    def create_gem_stubs(path, gem_specs)
      gem_specs.map do |spec|
        path = File.expand_path(File.join(path, '..', 'specifications', "#{spec.full_name}.gemspec"))
        %{
          Gem.loaded_specs["#{spec.name}"] = eval(File.read("#{path}"))
        }
      end.join("\n")
    end

    def create_fake_rubygems(path)
      File.open(File.join(path, "rubygems.rb"), "w") do |file|
        file.puts <<-RUBY_EVAL
          $:.delete File.expand_path(File.dirname(__FILE__))
          load "rubygems.rb"
          if defined?(Bundler) && Bundler.respond_to?(:rubygems_required)
            Bundler.rubygems_required
          end
        RUBY_EVAL
      end
    end

    def load_paths_for_specs(specs)
      load_paths = []
      specs.each do |spec|
        load_paths << File.join(spec.full_gem_path, spec.bindir) if spec.bindir
        spec.require_paths.each do |path|
          load_paths << File.join(spec.full_gem_path, path)
        end
      end
      load_paths
    end
  end
end