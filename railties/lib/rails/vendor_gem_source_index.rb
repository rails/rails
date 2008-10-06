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
        spec = load_specification(d)
        next unless spec
        # NOTE: this is a bit of a hack - the gem system expects a different structure
        # than we have.
        # It's looking for:
        # repository
        #   -> specifications
        #      - gem_name.spec      <= loaded_from points to this
        #   -> gems
        #      - gem_name           <= gem files here
        # and therefore goes up one directory from loaded_from, then adds gems/gem_name
        # to the path.
        # But we have:
        # vendor
        #   -> gems
        #      -> gem_name          <= gem files here
        #         - .specification
        # so we set loaded_from to vendor/gems/.specification (not a real file) to
        # get the correct behavior.
        spec.loaded_from = File.join(Rails::GemDependency.unpacked_path, '.specification')
        vendor_gems[File.basename(d)] = spec
      end
      @vendor_source_index = Gem::SourceIndex.new(vendor_gems)
    end

    def load_specification(gem_dir)
      spec_file = File.join(gem_dir, '.specification')
      YAML.load_file(spec_file) if File.exist?(spec_file)
    end

    def find_name(gem_name, version_requirement = Gem::Requirement.default)
      search(/^#{gem_name}$/, version_requirement)
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