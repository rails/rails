source "https://rubygems.org"

git_source(:github) { |repo_path| "https://github.com/#{repo_path}.git" }

gemspec

gem "rails", github: "rails/rails"

gem "rake"
gem "byebug"

gem "sqlite3"
gem "httparty"

gem "aws-sdk", "~> 2", require: false
gem "google-cloud-storage", "~> 1.3", require: false
# Contains fix to be able to test using StringIO
gem 'azure-core', git: "https://github.com/dixpac/azure-ruby-asm-core.git"
gem 'azure-storage', require: false

gem "mini_magick"

gem "rubocop", require: false
