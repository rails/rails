require 'rails/vendor_gem_source_index'

module Gem
  def self.source_index=(index)
    @@source_index = index
  end
end

module Rails
  class GemDependency
    attr_accessor :lib, :source

    def self.unpacked_path
      @unpacked_path ||= File.join(RAILS_ROOT, 'vendor', 'gems')
    end

    @@framework_gems = {}

    def self.add_frozen_gem_path
      @@paths_loaded ||= begin
        source_index = Rails::VendorGemSourceIndex.new(Gem.source_index)
        Gem.clear_paths
        Gem.source_index = source_index
        # loaded before us - we can't change them, so mark them
        Gem.loaded_specs.each do |name, spec|
          @@framework_gems[name] = spec
        end
        true
      end
    end

    def framework_gem?
      @@framework_gems.has_key?(name)
    end

    def vendor_rails?
      Gem.loaded_specs.has_key?(name) && Gem.loaded_specs[name].loaded_from.empty?
    end

    def vendor_gem?
      Gem.loaded_specs.has_key?(name) && Gem.loaded_specs[name].loaded_from.include?(self.class.unpacked_path)
    end

    def initialize(name, options = {})
      require 'rubygems' unless Object.const_defined?(:Gem)

      if options[:requirement]
        req = options[:requirement]
      elsif options[:version]
        req = Gem::Requirement.create(options[:version])
      else
        req = Gem::Requirement.default
      end

      @dep = Gem::Dependency.new(name, req)
      @lib      = options[:lib]
      @source   = options[:source]
      @loaded   = @frozen = @load_paths_added = false
    end

    def add_load_paths
      self.class.add_frozen_gem_path
      return if @loaded || @load_paths_added
      if framework_gem?
        @load_paths_added = @loaded = @frozen = true
        return
      end
      gem @dep
      @spec = Gem.loaded_specs[name]
      @frozen = @spec.loaded_from.include?(self.class.unpacked_path) if @spec
      @load_paths_added = true
    rescue Gem::LoadError
    end

    def dependencies
      return [] if framework_gem?
      all_dependencies = specification.dependencies.map do |dependency|
        GemDependency.new(dependency.name, :requirement => dependency.version_requirements)
      end
      all_dependencies += all_dependencies.map(&:dependencies).flatten
      all_dependencies.uniq
    end

    def gem_dir(base_directory)
      File.join(base_directory, specification.full_name)
    end

    def spec_filename(base_directory)
      File.join(gem_dir(base_directory), '.specification')
    end

    def load
      return if @loaded || @load_paths_added == false
      require(@lib || name) unless @lib == false
      @loaded = true
    rescue LoadError
      puts $!.to_s
      $!.backtrace.each { |b| puts b }
    end

    def name
      @dep.name.to_s
    end

    def requirement
      r = @dep.version_requirements
      (r == Gem::Requirement.default) ? nil : r
    end

    def frozen?
      @frozen ||= vendor_rails? || vendor_gem?
    end

    def loaded?
      @loaded ||= begin
        if vendor_rails?
          true
        elsif specification.nil?
          false
        else
          # check if the gem is loaded by inspecting $"
          # specification.files lists all the files contained in the gem
          gem_files = specification.files
          # select only the files contained in require_paths - typically in bin and lib
          require_paths_regexp = Regexp.new("^(#{specification.require_paths*'|'})/")
          gem_lib_files = gem_files.select { |f| require_paths_regexp.match(f) }
          # chop the leading directory off - a typical file might be in
          # lib/gem_name/file_name.rb, but it will be 'require'd as gem_name/file_name.rb
          gem_lib_files.map! { |f| f.split('/', 2)[1] }
          # if any of the files from the above list appear in $", the gem is assumed to
          # have been loaded
          !(gem_lib_files & $").empty?
        end
      end
    end

    def load_paths_added?
      # always try to add load paths - even if a gem is loaded, it may not
      # be a compatible version (ie random_gem 0.4 is loaded and a later spec
      # needs >= 0.5 - gem 'random_gem' will catch this and error out)
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

      # Gem.activate changes the spec - get the original
      real_spec = Gem::Specification.load(specification.loaded_from)
      write_spec(directory, real_spec)

    end

    def write_spec(directory, spec)
      # copy the gem's specification into GEMDIR/.specification so that
      # we can access information about the gem on deployment systems
      # without having the gem installed
      File.open(spec_filename(directory), 'w') do |file|
        file.puts spec.to_yaml
      end
    end

    def refresh_spec(directory)
      real_gems = Gem.source_index.installed_source_index
      exact_dep = Gem::Dependency.new(name, "= #{specification.version}")
      matches = real_gems.search(exact_dep)
      installed_spec = matches.first
      if File.exist?(File.dirname(spec_filename(directory)))
        if installed_spec
          # we have a real copy
          # get a fresh spec - matches should only have one element
          # note that there is no reliable method to check that the loaded
          # spec is the same as the copy from real_gems - Gem.activate changes
          # some of the fields
          real_spec = Gem::Specification.load(matches.first.loaded_from)
          write_spec(directory, real_spec)
          puts "Reloaded specification for #{name} from installed gems."
        else
          # the gem isn't installed locally - write out our current specs
          write_spec(directory, specification)
          puts "Gem #{name} not loaded locally - writing out current spec."
        end
      else
        if framework_gem?
          puts "Gem directory for #{name} not found - check if it's loading before rails."
        else
          puts "Something bad is going on - gem directory not found for #{name}."
        end
      end
    end

    def ==(other)
      self.name == other.name && self.requirement == other.requirement
    end
    alias_method :"eql?", :"=="

    def hash
      @dep.hash
    end

    def specification
      # code repeated from Gem.activate. Find a matching spec, or the currently loaded version.
      # error out if loaded version and requested version are incompatible.
      @spec ||= begin
        matches = Gem.source_index.search(@dep)
        matches << @@framework_gems[name] if framework_gem?
        if Gem.loaded_specs[name] then
          # This gem is already loaded.  If the currently loaded gem is not in the
          # list of candidate gems, then we have a version conflict.
          existing_spec = Gem.loaded_specs[name]
          unless matches.any? { |spec| spec.version == existing_spec.version } then
            raise Gem::Exception,
                  "can't activate #{@dep}, already activated #{existing_spec.full_name}"
          end
          # we're stuck with it, so change to match
          @dep.version_requirements = Gem::Requirement.create("=#{existing_spec.version}")
          existing_spec
        else
          # new load
          matches.last
        end
      end
    end

    private
      def gem_command
        RUBY_PLATFORM =~ /win32/ ? 'gem.bat' : 'gem'
      end

      def install_command
        cmd = %w(install) << name
        cmd << "--version" << %("#{requirement.to_s}") if requirement
        cmd << "--source"  << @source  if @source
        cmd
      end

      def unpack_command
        cmd = %w(unpack) << name
        cmd << "--version" << "= "+specification.version.to_s if requirement
        cmd
      end
  end
end
