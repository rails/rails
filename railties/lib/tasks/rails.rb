$VERBOSE = nil

# Load Rails rakefile extensions
Dir["#{File.dirname(__FILE__)}/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
Dir["./lib/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["./vendor/plugins/*/tasks/**/*.rake"].sort.each { |ext| load ext }