$VERBOSE = nil

# Load Rails rakefile extensions
%w(
  annotations
  databases
  documentation
  framework
  gems
  log
  middleware
  misc
  routes
  statistics
  testing
  tmp
).each do |task|
  load "rails/tasks/#{task}.rake"
end

# Load any custom rakefile extensions
# TODO: Don't hardcode these paths.
Dir["#{RAILS_ROOT}/vendor/plugins/*/**/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["#{RAILS_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
