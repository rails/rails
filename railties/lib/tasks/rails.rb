$VERBOSE = nil

# Load Rails rakefile extensions
Dir["#{File.dirname(__FILE__)}/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
Dir["#{RAILS_ROOT}/vendor/plugins/*/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["#{RAILS_ROOT}/vendor/plugins/*/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["#{RAILS_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
