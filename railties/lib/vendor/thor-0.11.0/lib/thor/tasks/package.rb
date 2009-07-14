require "fileutils"

class Thor
  # Creates a package task.
  #
  # ==== Parameters
  # spec<Gem::Specification>
  #
  # ==== Options
  # :dir - The package directory. Defaults to ./pkg.
  #
  def self.package_task(spec, options={})
    tasks['package'] = Thor::PackageTask.new(spec, options)
  end

  class PackageTask < Task
    attr_accessor :spec, :config

    def initialize(gemspec, config={})
      super(:package, "Build a gem package", "package", {})
      @spec   = gemspec
      @config = {:dir => File.join(Dir.pwd, "pkg")}.merge(config)
    end

    def run(instance, args=[])
      FileUtils.mkdir_p(config[:dir])
      Gem::Builder.new(spec).build
      FileUtils.mv(spec.file_name, File.join(config[:dir], spec.file_name))
    end
  end
end
