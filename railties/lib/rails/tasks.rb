# frozen_string_literal: true

# :markup: markdown
require "rake"

# Load Rails Rakefile extensions
%w(
  framework
  log
  misc
  tmp
  yarn
  zeitwerk
).each do |task|
  load "rails/tasks/#{task}.rake"
end
