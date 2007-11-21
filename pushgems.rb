#!/usr/bin/env ruby

unless ARGV.first == "no_build"
  build_number = build_number = `svn log -q -rhead http://dev.rubyonrails.org/svn/rails`.scan(/r([0-9]*)/).first.first.to_i
end

%w( activeresource actionmailer actionpack activerecord railties activesupport ).each do |pkg|
  puts "Pushing: #{pkg} (#{build_number})"
  if build_number
    `cd #{pkg} && rm -rf pkg && PKG_BUILD=#{build_number} rake pgem && cd ..`
  else
    `cd #{pkg} && rm -rf pkg && rake pgem && cd ..`
  end
end

