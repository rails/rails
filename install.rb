version = ARGV.pop

%w( activesupport activemodel activerecord actionpack actionmailer railties ).each do |framework|
  puts "Installing #{framework}..."
  `cd #{framework} && gem build #{framework}.gemspec && gem install #{framework}-#{version}.gem --no-ri --no-rdoc && rm #{framework}-#{version}.gem`
end

puts "Installing Rails..."
`gem build rails.gemspec`
`gem install rails-#{version}.gem --no-ri --no-rdoc `
`rm rails-#{version}.gem`
