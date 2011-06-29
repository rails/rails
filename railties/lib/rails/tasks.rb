$VERBOSE = nil

# Load Rails rakefile extensions
%w(
  annotations
  documentation
  framework
  log
  middleware
  misc
  routes
  statistics
  tmp
).each do |task|
  load "rails/tasks/#{task}.rake"
end
