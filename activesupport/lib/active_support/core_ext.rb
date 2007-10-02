Dir[File.dirname(__FILE__) + "/core_ext/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_support/core_ext/#{filename}"
end
