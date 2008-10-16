require 'rubygems'
require 'yaml'

module Rails

  class VendorGemSourceIndex
    # VendorGemSourceIndex acts as a proxy for the Gem source index, allowing
    # gems to be loaded from vendor/gems. Rather than the standard gem repository format,
    # vendor/gems contains unpacked gems, with YAML specifications in .specification in
    # each gem directory.
    include Enumerable

    attr_reader :installed_source_index
    attr_reader :vendor_source_index

    @@silence_spec_warnings = false

    def self.silence_spec_warnings
      @@silence_spec_warnings
    end

    def self.silence_spec_warnings=(v)
      @@silence_spec_warnings = v
    end

    def initialize(installed_index, vendor_dir=Rails::GemDependency.unpacked_path)
      @installed_source_index = installed_index
      @vendor_dir = vendor_dir
      refresh!
    end

    def refresh!
      # reload the installed gems
      @installed_source_index.refresh!
      vendor_gems = {}

      # handle vendor Rails gems - they are identified by having loaded_from set to ""
      # we add them manually to the list, so that other gems can find them via dependencies
      Gem.loaded_specs.each do |n, s|
        next unless s.loaded_from.empty?
        vendor_gems[s.full_name] = s
      end

      # load specifications from vendor/gems
      Dir[File.join(Rails::GemDependency.unpacked_path, '*')].each do |d|
        dir_name = File.basename(d)
        dir_version = version_for_dir(dir_name)
        spec = load_specification(d)
        if spec
          if spec.full_name != dir_name
            # mismatched directory name and gem spec - produced by 2.1.0-era unpack code
            if dir_version
              # fix the spec version - this is not optimal (spec.files may be wrong)
              # but it's better than breaking apps. Complain to remind users to get correct specs.
              # use ActiveSupport::Deprecation.warn, as the logger is not set yet
              $stderr.puts("config.gem: Unpacked gem #{dir_name} in vendor/gems has a mismatched specification file."+
                           " Run 'rake gems:refresh_specs' to fix this.") unless @@silence_spec_warnings
              spec.version = dir_version
            else
              $stderr.puts("config.gem: Unpacked gem #{dir_name} in vendor/gems is not in a versioned directory"+
                           "(should be #{spec.full_name}).") unless @@silence_spec_warnings
              # continue, assume everything is OK
            end
          end
        else
          # no spec - produced by early-2008 unpack code
          # emulate old behavior, and complain.
          $stderr.puts("config.gem: Unpacked gem #{dir_name} in vendor/gems has no specification file."+
                       " Run 'rake gems:refresh_specs' to fix this.") unless @@silence_spec_warnings
          if dir_version
            spec = Gem::Specification.new
            spec.version = dir_version
            spec.require_paths = ['lib']
            ext_path = File.join(d, 'ext')
            spec.require_paths << 'ext' if File.exist?(ext_path)
            spec.name = /^(.*)-[^-]+$/.match(dir_name)[1]
            files = ['lib']
            # set files to everything in lib/
            files += Dir[File.join(d, 'lib', '*')].map { |v| v.gsub(/^#{d}\//, '') }
            files += Dir[File.join(d, 'ext', '*')].map { |v| v.gsub(/^#{d}\//, '') } if ext_path
            spec.files = files
          else
            $stderr.puts("config.gem: Unpacked gem #{dir_name} in vendor/gems not in a versioned directory."+
                         " Giving up.") unless @silence_spec_warnings
            next
          end
        end
        spec.loaded_from = File.join(d, '.specification')
        # finally, swap out full_gem_path
        # it would be better to use a Gem::Specification subclass, but the YAML loads an explicit class
        class << spec
          def full_gem_path
            path = File.join installation_path, full_name
            return path if File.directory? path
            File.join installation_path, original_name
          end
        end
        vendor_gems[File.basename(d)] = spec
      end
      @vendor_source_index = Gem::SourceIndex.new(vendor_gems)
    end

    def version_for_dir(d)
      matches = /-([^-]+)$/.match(d)
      Gem::Version.new(matches[1]) if matches
    end

    def load_specification(gem_dir)
      spec_file = File.join(gem_dir, '.specification')
      YAML.load_file(spec_file) if File.exist?(spec_file)
    end

    def find_name(*args)
      @installed_source_index.find_name(*args) + @vendor_source_index.find_name(*args)
    end

    def search(*args)
      # look for vendor gems, and then installed gems - later elements take priority
      @installed_source_index.search(*args) + @vendor_source_index.search(*args)
    end

    def each(&block)
      @vendor_source_index.each(&block)
      @installed_source_index.each(&block)
    end

    def add_spec(spec)
      @vendor_source_index.add_spec spec
    end

    def remove_spec(spec)
      @vendor_source_index.remove_spec spec
    end

    def size
      @vendor_source_index.size + @installed_source_index.size
    end

  end
end