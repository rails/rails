require "rubygems"
gem 'hoe', '>= 2.1.0'
require 'hoe'

Hoe.plugin :isolate
Hoe.plugin :gemspec # `gem install hoe-gemspec`

Hoe.spec 'arel' do
  developer('Aaron Patterson', 'aaron@tenderlovemaking.com')
  developer('Bryan Halmkamp', 'bryan@brynary.com')
  developer('Emilio Tagua', 'miloops@gmail.com')
  developer('Nick Kallen', 'nick@example.org') # FIXME: need Nick's email

  self.readme_file      = 'README.markdown'
  self.extra_rdoc_files = FileList['README.markdown']
  self.extra_dev_deps << ['rspec', '~> 1.3.0']
  self.extra_dev_deps << ['ZenTest']
  self.extra_dev_deps << ['minitest']
  self.extra_dev_deps << ['hoe-gemspec']
  self.testlib = :minitest
end
