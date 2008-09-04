#!/usr/bin/env ruby

VERSION  = ARGV.first
PACKAGES = %w(activesupport activerecord actionpack actionmailer activeresource)

# Copy source
`mkdir release`
(PACKAGES + %w(railties)).each do |p| 
  `cp -R #{p} release/#{p}`
end

# Create Rails packages
`cd release/railties && rake template=jamis package`

# Upload documentation
`cd release/rails/doc/api && scp -r * davidhh@wrath.rubyonrails.com:public_html/api`

# Upload packages
(PACKAGES + %w(railties)).each do |p| 
  `cd release/#{p} && echo "Releasing #{p}" && rake release`
end

# Upload rails tgz/zip
`rubyforge add_release rails rails 'REL #{VERSION}' release/rails-#{VERSION}.tgz`
`rubyforge add_release rails rails 'REL #{VERSION}' release/rails-#{VERSION}.zip`