$VERBOSE = nil

# Load Rails rakefile extensions
Dir["#{File.dirname(__FILE__)}/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
deprecated_paths = Dir["#{RAILS_ROOT}/vendor/plugins/*/tasks/**/*.rake"].sort
if deprecated_paths.any?
  plugins = deprecated_paths.map { |p| $1 if p =~ %r((vendor/plugins/[^/]+/tasks)) }.compact
  ActiveSupport::Deprecation.warn "Rake tasks in #{plugins.to_sentence} are deprecated. Use lib/tasks instead."
  deprecated_paths.each { |ext| load ext }
end
Dir["#{RAILS_ROOT}/vendor/plugins/*/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["#{RAILS_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
