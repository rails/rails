BUNDLER_ENV_FILE = File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'environment')

def load_bundled_gems
  load_bundled_gems! if File.exist?("#{BUNDLER_ENV_FILE}.rb")
end

def load_bundled_gems!
  puts "Checking if the bundled testing requirements are up to date..."

  result = system "gem bundle"
  unless result
    puts "The gem bundler is not installed. Installing."
    system "gem install bundler"
    system "gem bundle"
  end

  require BUNDLER_ENV_FILE
end

def ensure_requirable(libs)
  load_bundled_gems

  begin
    libs.each { |lib| require lib }
  rescue LoadError => e
    puts "Missing required libs to run test"
    puts e.message
    load_bundled_gems!
  end
end
