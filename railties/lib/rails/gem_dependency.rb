module Rails
  class GemDependency
    attr_accessor :name, :requirement, :version, :lib, :source

    def self.unpacked_path
      @unpacked_path ||= File.join(RAILS_ROOT, 'vendor', 'gems')
    end

    def initialize(name, options = {})
      @name     = name.to_s
      if options[:version]
        @requirement = Gem::Requirement.create(options[:version])
        @version     = @requirement.instance_variable_get("@requirements").first.last
      end
      @lib      = options[:lib]
      @source   = options[:source]
      @loaded   = false
      @load_paths_added = false
      @unpack_directory = nil
    end

    def add_load_paths
      return if @loaded || @load_paths_added
      unpacked_paths = Dir[File.join(self.class.unpacked_path, "#{@name}-#{@version || "*"}")]
      if unpacked_paths.empty?
        args = [@name]
        args << @requirement.to_s if @requirement
        gem *args
      else
        $LOAD_PATH << File.join(unpacked_paths.first, 'lib')
      end
      @load_paths_added = true
    rescue Gem::LoadError
      puts $!.to_s
    end

    def load
      return if @loaded || @load_paths_added == false
      require(@lib || @name)
      @loaded = true
    rescue LoadError
      puts $!.to_s
      $!.backtrace.each { |b| puts b }
    end

    def loaded?
      @loaded
    end

    def load_paths_added?
      @load_paths_added
    end

    def install
      Gem::GemRunner.new.run(install_command)
    end

    def unpack_to(directory)
      FileUtils.mkdir_p directory
      Dir.chdir directory do
        Gem::GemRunner.new.run(unpack_command)
      end
    end

    def install_command
      cmd = %w(install) << @name
      cmd << "--version" << "#{@requirement.to_s}" if @requirement
      cmd << "--source"  << @source  if @source
      cmd
    end
    
    def unpack_command
      cmd = %w(unpack) << @name
      cmd << "--version" << "#{@requirement.to_s}" if @requirement
      cmd
    end
  end
end