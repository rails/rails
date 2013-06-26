Dir["#{File.dirname(__FILE__)}/core_ext/*.rb"].each do |path|
  next if File.basename(path, '.rb') == 'logger'
  require path
end
