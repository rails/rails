require 'rake'

# Load Rails Rakefile extensions
%w(
  annotations
  dev
  framework
  initializer
  log
  middleware
  misc
  restart
  routes
  statistics
  tmp
).each do |task|
  load "rails/tasks/#{task}.rake"
end
