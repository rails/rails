task :default => :test
task :environment do
  require(File.join(RAILS_ROOT, 'config', 'environment'))
end

require 'rails_generator/secret_key_generator'
desc 'Generate a crytographically secure secret key. This is typically used to generate a secret for cookie sessions. Pass a unique identifier to the generator using ID="some unique identifier" for greater security.'
task :secret do
  puts Rails::SecretKeyGenerator.new(ENV['ID']).generate_secret
end
