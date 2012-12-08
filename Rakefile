require "rubygems"
gem 'hoe', '>= 3.3.1'
require 'hoe'

Hoe.plugins.delete :rubyforge
Hoe.plugin :minitest
Hoe.plugin :gemspec # `gem install hoe-gemspec`
Hoe.plugin :git     # `gem install hoe-git`
Hoe.plugin :bundler # `gem install hoe-bundler`

Hoe.spec 'arel' do
  developer('Aaron Patterson', 'aaron@tenderlovemaking.com')
  developer('Bryan Halmkamp', 'bryan@brynary.com')
  developer('Emilio Tagua', 'miloops@gmail.com')
  developer('Nick Kallen', 'nick@example.org') # FIXME: need Nick's email

  self.readme_file      = 'README.markdown'
  self.extra_rdoc_files = FileList['README.markdown']
end
