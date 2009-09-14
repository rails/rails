def ensure_requirable(libs)
  bundler = File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'environment')
  require bundler if File.exist?("#{bundler}.rb")

  begin
    libs.each { |lib| require lib }
  rescue LoadError => e
    puts e.message
    exit 1
  end
end
