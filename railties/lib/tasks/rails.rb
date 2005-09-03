$VERBOSE = nil

# Load Rails rakefile extensions
Dir["#{File.dirname(__FILE__)}/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
Dir["./config/tasks/**/*.rake"].each { |ext| load ext }