Gem.sources.each { |uri| source uri }

gem "rails", "3.0.pre", :vendored_at => "railties"
%w(
  activesupport
  activemodel
  actionpack
  actionmailer
  activerecord
  activeresource
).each do |lib|
  gem lib, '3.0.pre', :vendored_at => lib
end
gem "rack",          "1.0.1"
gem "rack-mount",    :git => "git://github.com/rails/rack-mount.git"
gem "rack-test",     "~> 0.5.0"
gem "erubis",        "~> 2.6.0"
gem "arel",          :git => "git://github.com/rails/arel.git"
gem "mocha"
gem "sqlite3-ruby"
gem "RedCloth"
