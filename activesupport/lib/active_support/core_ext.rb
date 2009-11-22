filenames = Dir["#{File.dirname(__FILE__)}/core_ext/*.rb"].sort.map do |path|
  File.basename(path, '.rb')
end

# deprecated
filenames -= %w(blank)

filenames.each { |filename| require "active_support/core_ext/#{filename}" }
