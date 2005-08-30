#!/usr/local/bin/ruby

unless ARGV.first == "no_build"
  build_number = "1962"
end

%w( actionwebservice actionmailer actionpack activerecord railties activesupport ).each do |pkg|
  puts "Pushing: #{pkg} (#{build_number})"
  if build_number
    `cd #{pkg} && rm -rf pkg && PKG_BUILD=#{build_number} rake pgem && cd ..`
  else
    `cd #{pkg} && rm -rf pkg && rake pgem && cd ..`
  end
end
