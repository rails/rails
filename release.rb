#!/usr/local/bin/ruby

PACKAGES = %w( activesupport activerecord actionpack actionmailer actionwebservice )

unless ruby_forge_password = ARGV.first
  print "rubyforge.org's password: "
  ruby_forge_password = STDIN.gets.chomp
end

# Checkout source
`rm -rf release && svn export http://dev.rubyonrails.org/svn/rails/trunk release`

# Create Rails packages
`cd release/railties && rake template=jamis package`

# Upload documentation
`cd release/rails/doc/api && scp -r * davidhh@wrath.rubyonrails.com:public_html/rails`
PACKAGES.each do |p| 
  `cd release/#{p} && echo "Publishing documentation for #{p}" && rake template=jamis pdoc`
end

# Upload packages
(PACKAGES + %w(railties)).each do |p| 
  `cd release/#{p} && echo "Releasing #{p}" && RUBY_FORGE_PASSWORD=#{ruby_forge_password} rake release`
end

# Upload rails tgz/zip

# Create SVN tag
`cd ..; svn cp trunk tags/rel_#{ARGV[1]}`
