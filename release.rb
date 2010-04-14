version = ARGV.pop

%w( activesupport activemodel activerecord activeresource actionpack actionmailer railties ).each do |framework|
  puts "Building and pushing #{framework}..."
  `cd #{framework} && gem build #{framework}.gemspec && gem push #{framework}-#{version}.gem && rm #{framework}-#{version}.gem`
end

puts "Building and pushing Rails..."
`gem build rails.gemspec`
`gem push rails-#{version}.gem`
`rm rails-#{version}.gem`