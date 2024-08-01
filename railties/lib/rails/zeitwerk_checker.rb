# frozen_string_literal: true

# The actual (private) implementation of the Rake task zeitwerk:check.
class Rails::ZeitwerkChecker # :nodoc:
  def self.check
    Zeitwerk::Loader.eager_load_all

    autoloaded = ActiveSupport::Dependencies.autoload_paths + ActiveSupport::Dependencies.autoload_once_paths
    eager_loaded = ActiveSupport::Dependencies._eager_load_paths.to_a

    unchecked = autoloaded - eager_loaded
    unchecked.select! { |dir| Dir.exist?(dir) && !Dir.empty?(dir)  }
    unchecked
  end
end
