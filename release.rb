#!/usr/local/bin/ruby

VERSION  = ARGV.first
PACKAGES = %w( activesupport activerecord actionpack actionmailer actionwebservice )

# Checkout source
`rm -rf release && svn export http://dev.rubyonrails.org/svn/rails/trunk release`

# Create Rails packages
`cd release/railties && rake template=jamis package`

# Upload documentation
`cd release/rails/doc/api && scp -r * davidhh@wrath.rubyonrails.com:public_html/api`

# Upload packages
(PACKAGES + %w(railties)).each do |p| 
  `cd release/#{p} && echo "Releasing #{p}" && rake release`
end

# Upload rails tgz/zip
`rubyforge add_release rails rails 'REL #{VERSION}' rails-#{VERSION}.tgz`
`rubyforge add_release rails rails 'REL #{VERSION}' rails-#{VERSION}.zip`

# Create SVN tag
puts "Remember to create SVN tag"
