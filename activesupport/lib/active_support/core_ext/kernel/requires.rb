require 'active_support/core_ext/kernel/reporting'

module Kernel
  # Require a library with fallback to RubyGems.  Warnings during library
  # loading are silenced to increase signal/noise for application warnings.
  def require_library_or_gem(library_name)
    silence_warnings do
      begin
        require library_name
      rescue LoadError => cannot_require
        # 1. Requiring the module is unsuccessful, maybe it's a gem and nobody required rubygems yet. Try.
        begin
          require 'rubygems'
        rescue LoadError # => rubygems_not_installed
          raise cannot_require
        end
        # 2. Rubygems is installed and loaded. Try to load the library again
        begin
          require library_name
        rescue LoadError # => gem_not_installed
          raise cannot_require
        end
      end
    end
  end
end
