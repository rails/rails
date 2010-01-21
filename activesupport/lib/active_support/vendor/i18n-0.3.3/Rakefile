task :default => [:test]

task :test do
  ruby "test/all.rb"
end

require File.expand_path("lib/i18n/version", File.dirname(__FILE__))

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "i18n"
    s.version = I18n::VERSION
    s.rubyforge_project = "i18n"
    s.summary = "New wave Internationalization support for Ruby"
    s.email = "rails-i18n@googlegroups.com"
    s.homepage = "http://rails-i18n.org"
    s.description = "Add Internationalization support to your Ruby application."
    s.authors = ['Sven Fuchs', 'Joshua Harvey', 'Matt Aimonetti', 'Stephan Soller', 'Saimon Moore']
    s.files =  FileList["[A-Z]*", "{lib,test,vendor}/**/*"]
  end
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
