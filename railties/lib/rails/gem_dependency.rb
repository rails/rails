require 'rails/vendor_gem_source_index'

module Gem
  def self.source_index=(index)
    @@source_index = index
  end
end

module Rails
  class GemDependency < Gem::Dependency
    attr_accessor :lib, :source, :dep

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

    def self.from_directory_name(directory_name)
      directory_name_parts = File.basename(directory_name).split('-')
      name    = directory_name_parts[0..-2].join('-')
      version = directory_name_parts.last
      self.new(name, :version => version)
    rescue ArgumentError => e
      raise "Unable to determine gem name and version from '#{directory_name}'"
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

      @lib      = options[:lib]
      @source   = options[:source]
      @loaded   = @frozen = @load_paths_added = false

      super(name, req)
    end

    def add_load_paths
      self.class.add_frozen_gem_path
      return if @loaded || @load_paths_added
      if framework_gem?
        @load_paths_added = @loaded = @frozen = true
        return
      end
      gem self
      @spec = Gem.loaded_specs[name]
      @frozen = @spec.loaded_from.include?(self.class.unpacked_path) if @spec
      @load_paths_added = true
    rescue Gem::LoadError
    end

    def dependencies
      return [] if framework_gem?
      return [] unless installed?
      specification.dependencies.reject do |dependency|
        dependency.type == :development
      end.map do |dependency|
        GemDependency.new(dependency.name, :requirement => dependency.version_requirements)
      end
    end

    def specification
      # code repeated from Gem.activate. Find a matching spec, or the currently loaded version.
      # error out if loaded version and requested version are incompatible.
      @spec ||= begin
        matches = Gem.source_index.search(self)
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
          version_requirements = Gem::Requirement.create("=#{existing_spec.version}")
          existing_spec
        else
          # new load
          matches.last
        end
      end
    end

    def requirement
      r = version_requirements
      (r == Gem::Requirement.default) ? nil : r
    end

    def built?
      return false unless frozen?
      specification.extensions.each do |ext|
        makefile = File.join(unpacked_gem_directory, File.dirname(ext), 'Makefile')
        return false unless File.exists?(makefile)
      end
      true
    end

    def framework_gem?
      @@framework_gems.has_key?(name)
    end

    def frozen?
      @frozen ||= vendor_rails? || vendor_gem?
    end

    def installed?
      Gem.loaded_specs.keys.include?(name)
    end

    def load_paths_added?
      # always try to add load paths - even if a gem is loaded, it may not
      # be a compatible version (ie random_gem 0.4 is loaded and a later spec
      # needs >= 0.5 - gem 'random_gem' will catch this and error out)
      @load_paths_added
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

    def vendor_rails?
      Gem.loaded_specs.has_key?(name) && Gem.loaded_specs[name].loaded_from.empty?
    end

    def vendor_gem?
      specification && File.exists?(unpacked_gem_directory)
    end

    def build(options={})
      require 'rails/gem_builder'
      if options[:force] || !built?
        return unless File.exists?(unpacked_specification_filename)
        spec = YAML::load_file(unpacked_specification_filename)
        Rails::GemBuilder.new(spec, unpacked_gem_directory).build_extensions
        puts "Built gem: '#{unpacked_gem_directory}'"
      end
      dependencies.each { |dep| dep.build }
    end

    def install
      unless installed?
        cmd = "#{gem_command} #{install_command.join(' ')}"
        puts cmd
        puts %x(#{cmd})
      end
    end

    def load
      return if @loaded || @load_paths_added == false
      require(@lib || name) unless @lib == false
      @loaded = true
    rescue LoadError
      puts $!.to_s
      $!.backtrace.each { |b| puts b }
    end

    def refresh
      Rails::VendorGemSourceIndex.silence_spec_warnings = true
      real_gems = Gem.source_index.installed_source_index
      exact_dep = Gem::Dependency.new(name, "= #{specification.version}")
      matches = real_gems.search(exact_dep)
      installed_spec = matches.first
      if frozen?
        if installed_spec
          # we have a real copy
          # get a fresh spec - matches should only have one element
          # note that there is no reliable method to check that the loaded
          # spec is the same as the copy from real_gems - Gem.activate changes
          # some of the fields
          real_spec = Gem::Specification.load(matches.first.loaded_from)
          write_specification(real_spec)
          puts "Reloaded specification for #{name} from installed gems."
        else
          # the gem isn't installed locally - write out our current specs
          write_specification(specification)
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

    def unpack(options={})
      unless frozen? || framework_gem?
        FileUtils.mkdir_p unpack_base
        Dir.chdir unpack_base do
          Gem::GemRunner.new.run(unpack_command)
        end
        # Gem.activate changes the spec - get the original
        real_spec = Gem::Specification.load(specification.loaded_from)
        write_specification(real_spec)
      end
      dependencies.each { |dep| dep.unpack } if options[:recursive]
    end

    def write_specification(spec)
      # copy the gem's specification into GEMDIR/.specification so that
      # we can access information about the gem on deployment systems
      # without having the gem installed
      File.open(unpacked_specification_filename, 'w') do |file|
        file.puts spec.to_yaml
      end
    end

    def ==(other)
      self.name == other.name && self.requirement == other.requirement
    end
    alias_method :"eql?", :"=="

    private

      def gem_command
        case RUBY_PLATFORM
          when /win32/
            'gem.bat'
          when /java/
            'jruby -S gem'
          else
            'gem'
        end
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

      def unpack_base
        Rails::GemDependency.unpacked_path
      end

      def unpacked_gem_directory
        File.join(unpack_base, specification.full_name)
      end

      def unpacked_specification_filename
        File.join(unpacked_gem_directory, '.specification')
      end

  end
end
