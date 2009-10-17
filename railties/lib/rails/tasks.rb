$VERBOSE = nil

# Load Rails rakefile extensions
%w(
  annotations
  databases
  documentation
  framework
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
Dir["#{Rails.root}/vendor/plugins/*/**/tasks/**/*.rake"].sort.each { |ext| load ext }
Dir["#{Rails.root}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
