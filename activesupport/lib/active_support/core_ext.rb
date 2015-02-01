DEPRECATED_FILES = ["#{File.dirname(__FILE__)}/core_ext/struct.rb"]
(Dir["#{File.dirname(__FILE__)}/core_ext/*.rb"] - DEPRECATED_FILES).each do |path|
  require path
end
