class Thor
  # Creates an install task.
  #
  # ==== Parameters
  # spec<Gem::Specification>
  #
  # ==== Options
  # :dir - The directory where the package is hold before installation. Defaults to ./pkg.
  #
  def self.install_task(spec, options={})
    package_task(spec, options)
    tasks['install'] = Thor::InstallTask.new(spec, options)
  end

  class InstallTask < Task
    attr_accessor :spec, :config

    def initialize(gemspec, config={})
      super(:install, "Install the gem", "install", {})
      @spec   = gemspec
      @config = { :dir => File.join(Dir.pwd, "pkg") }.merge(config)
    end

    def run(instance, args=[])
      null, sudo, gem = RUBY_PLATFORM =~ /mswin|mingw/ ? ['NUL', '', 'gem.bat'] :
                                                         ['/dev/null', 'sudo', 'gem']

      old_stderr, $stderr = $stderr.dup, File.open(null, "w")
      instance.invoke(:package)
      $stderr = old_stderr

      system %{#{sudo} #{Gem.ruby} -S #{gem} install #{config[:dir]}/#{spec.name}-#{spec.version} --no-rdoc --no-ri --no-update-sources}
    end
  end
end
