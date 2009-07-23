require "fileutils"

class Thor
  # Creates a spec task.
  #
  # ==== Parameters
  # files<Array> - Array of files to spec
  #
  # ==== Options
  # :name     - The name of the task. It can be rcov or spec. Spec is the default.
  # :rcov     - A hash with rcov specific options.
  # :rcov_dir - Where rcov reports should be printed.
  # :verbose  - Sets the default value for verbose, although it can be specified
  #             also through the command line.
  #
  # All other options are added to rspec.
  #
  def self.spec_task(files, options={})
    name        = (options.delete(:name) || 'spec').to_s
    tasks[name] = Thor::SpecTask.new(name, files, options)
  end

  class SpecTask < Task
    attr_accessor :name, :files, :rcov_dir, :rcov_config, :spec_config

    def initialize(name, files, config={})
      options = { :verbose => Thor::Option.parse(:verbose, config.delete(:verbose) || false) }
      super(name, "#{name.capitalize} task", name, options)

      @name        = name
      @files       = files.map{ |f| %["#{f}"] }.join(" ")
      @rcov_dir    = config.delete(:rdoc_dir) || File.join(Dir.pwd, 'coverage')
      @rcov_config = config.delete(:rcov) || {}
      @spec_config = { :format => 'specdoc', :color => true }.merge(config)
    end

    def run(instance, args=[])
      rcov_opts = Thor::Options.to_switches(rcov_config)
      spec_opts = Thor::Options.to_switches(spec_config)

      require 'rbconfig'
      cmd  = RbConfig::CONFIG['ruby_install_name'] << " "

      if rcov?
        FileUtils.rm_rf(rcov_dir)
        cmd << "-S #{where('rcov')} -o #{rcov_dir} #{rcov_opts} "
      end

      cmd << [where('spec'), rcov? ? " -- " : nil, files, spec_opts].join(" ")

      puts cmd if instance.options.verbose?
      system(cmd)
      exit($?.exitstatus)
    end

    private

      def rcov?
        name == "rcov"
      end

      def where(file)
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          file_with_path = File.join(path, file)
          next unless File.exist?(file_with_path) && File.executable?(file_with_path)
          return File.expand_path(file_with_path)
        end
      end
  end
end
