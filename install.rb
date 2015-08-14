# Usage: ruby install.rb

version = File.read(File.expand_path('../RAILS_VERSION', __FILE__)).strip

%w( activesupport activemodel activerecord actionpack actionview actionmailer railties activejob ).each do |framework|
  puts "Installing #{framework}..."
  `cd #{framework} && gem build #{framework}.gemspec && gem install #{framework}-#{version}.gem --no-document && rm #{framework}-#{version}.gem`
end

puts "Installing rails..."
`gem build rails.gemspec`
`gem install rails-#{version}.gem --no-document `
`rm rails-#{version}.gem`
