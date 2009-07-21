module Bundler
  class Installer
    def initialize(path)
      if !File.directory?(path)
        raise ArgumentError, "#{path} is not a directory"
      elsif !File.directory?(File.join(path, "cache"))
        raise ArgumentError, "#{path} is not a valid environment (it does not contain a cache directory)"
      end

      @path = path
      @gems = Dir[(File.join(path, "cache", "*.gem"))]
    end

    def install(options = {})
      bin_dir = options[:bin_dir] ||= File.join(@path, "bin")

      specs = Dir[File.join(@path, "specifications", "*.gemspec")]
      gems  = Dir[File.join(@path, "gems", "*")]

      @gems.each do |gem|
        name      = File.basename(gem).gsub(/\.gem$/, '')
        installed = specs.any? { |g| File.basename(g) == "#{name}.gemspec" } &&
          gems.any? { |g| File.basename(g) == name }

        unless installed
          installer = Gem::Installer.new(gem, :install_dir => @path,
            :ignore_dependencies => true,
            :env_shebang => true,
            :wrappers => true,
            :bin_dir => bin_dir)
          installer.install
        end

        # remove this spec
        specs.delete_if { |g| File.basename(g) == "#{name}.gemspec"}
        gems.delete_if  { |g| File.basename(g) == name }
      end

      (specs + gems).each do |path|
        FileUtils.rm_rf(path)
      end
    end
  end
end