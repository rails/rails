require 'active_support/core'
Dir["#{File.dirname(__FILE__)}/core/*.rb"].sort.each do |path|
  require "active_support/core/#{File.basename(path, '.rb')}"
end
