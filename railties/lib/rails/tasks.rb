# Load Rails Rakefile extensions
%w(
  annotations
  documentation
  framework
  log
  middleware
  misc
  routes
  tmp
).each do |task|
  load "rails/tasks/#{task}.rake"
end
