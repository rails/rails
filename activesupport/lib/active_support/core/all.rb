require 'active_support/core_ext'
require 'active_support/core'
Dir["#{File.dirname(__FILE__)}/*.rb"].sort.each do |path|
  require "active_support/core/#{File.basename(path, '.rb')}"
end
