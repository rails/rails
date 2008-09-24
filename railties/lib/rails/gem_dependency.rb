module Rails
  class GemDependency
    attr_accessor :name, :requirement, :version, :lib, :source

    def self.unpacked_path
      @unpacked_path ||= File.join(RAILS_ROOT, 'vendor', 'gems')
    end

    def initialize(name, options = {})
      require 'rubygems' unless Object.const_defined?(:Gem)

      if options[:requirement]
        @requirement = options[:requirement]
      elsif options[:version]
        @requirement = Gem::Requirement.create(options[:version])
      end

      @version  = @requirement.instance_variable_get("@requirements").first.last if @requirement
      @name     = name.to_s
      @lib      = options[:lib]
      @source   = options[:source]
      @loaded   = @frozen = @load_paths_added = false
      @unpack_directory = nil
    end

    def unpacked_paths
      Dir[File.join(self.class.unpacked_path, "#{@name}-#{@version || "*"}")]
    end

    def add_load_paths
      return if @loaded || @load_paths_added
      unpacked_paths = self.unpacked_paths
      if unpacked_paths.empty?
        args = [@name]
        args << @requirement.to_s if @requirement
        gem *args
      else
        $LOAD_PATH.unshift File.join(unpacked_paths.first, 'lib')
        ext = File.join(unpacked_paths.first, 'ext')
        $LOAD_PATH.unshift(ext) if File.exist?(ext)
        @frozen = true
      end
      @load_paths_added = true
    rescue Gem::LoadError
    end

    def dependencies
      all_dependencies = specification.dependencies.map do |dependency|
        GemDependency.new(dependency.name, :requirement => dependency.version_requirements)
      end
      all_dependencies += all_dependencies.map(&:dependencies).flatten
      all_dependencies.uniq
    end

    def gem_dir(base_directory)
      File.join(base_directory, specification.full_name)
    end

    def load
      return if @loaded || @load_paths_added == false
      require(@lib || @name) unless @lib == false
      @loaded = true
    rescue LoadError
      puts $!.to_s
      $!.backtrace.each { |b| puts b }
    end

    def frozen?
      @frozen
    end

    def loaded?
      @loaded
    end

    def load_paths_added?
      @load_paths_added
    end

    def install
      cmd = "#{gem_command} #{install_command.join(' ')}"
      puts cmd
      puts %x(#{cmd})
    end

    def unpack_to(directory)
      FileUtils.mkdir_p directory
      Dir.chdir directory do
        Gem::GemRunner.new.run(unpack_command)
      end

      # copy the gem's specification into GEMDIR/.specification so that
      # we can access information about the gem on deployment systems
      # without having the gem installed
      spec_filename = File.join(gem_dir(directory), '.specification')
      File.open(spec_filename, 'w') do |file|
        file.puts specification.to_yaml
      end
    end

    def ==(other)
      self.name == other.name && self.requirement == other.requirement
    end

    def specification
      @spec ||= Gem.source_index.search(Gem::Dependency.new(@name, @requirement)).sort_by { |s| s.version }.last
    end

    private
      def gem_command
        RUBY_PLATFORM =~ /win32/ ? 'gem.bat' : 'gem'
      end

      def install_command
        cmd = %w(install) << @name
        cmd << "--version" << %("#{@requirement.to_s}") if @requirement
        cmd << "--source"  << @source  if @source
        cmd
      end

      def unpack_command
        cmd = %w(unpack) << @name
        # We don't quote this requirement as it's run through GemRunner instead
        # of shelling out to gem
        cmd << "--version" << @requirement.to_s if @requirement
        cmd
      end
  end
end
