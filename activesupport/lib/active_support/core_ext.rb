(Dir["#{File.dirname(__FILE__)}/core_ext/*.rb"]).each do |path|
  require path
end
