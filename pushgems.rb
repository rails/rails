#!/usr/local/bin/ruby

build_number = `svn log -q -rhead http://dev.rubyonrails.org/svn/rails`.scan(/r([0-9]*)/).first.first.to_i

(%w( actionservice actionmailer actionpack activerecord railties activesupport) - ARGV).each do |pkg|
  puts "Pushing: #{pkg} (#{build_number})"
  `cd #{pkg} && PKG_BUILD=#{build_number} rake pgem && cd ..`
end
