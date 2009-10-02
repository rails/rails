module Gem
  class Installer
    def app_script_text(bin_file_name)
      path = @gem_home
      template = File.read(File.join(File.dirname(__FILE__), "templates", "app_script.erb"))
      erb = ERB.new(template, nil, '-')
      erb.result(binding)
    end
  end

  class Specification
    attr_accessor :source
    attr_accessor :location

    # Hack to fix github's strange marshal file
    def specification_version
      @specification_version && @specification_version.to_i
    end

    alias full_gem_path_without_location full_gem_path
    def full_gem_path
      @location ? @location : full_gem_path_without_location
    end
  end
end
