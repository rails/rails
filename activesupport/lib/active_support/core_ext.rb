Dir[File.dirname(__FILE__) + "/core_ext/*.rb"].sort.each do |path|
  filename = File.basename(path, '.rb')
  require "active_support/core_ext/#{filename}"
end
