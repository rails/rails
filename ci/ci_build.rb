#!/usr/bin/env ruby
require 'fileutils'
include FileUtils

def root_dir
  @root_dir ||= File.expand_path('../..', __FILE__)
end

def rake(*tasks)
  tasks.each { |task| return false unless system("bundle exec rake", task) }
  true
end

puts "[CruiseControl] Rails build"
build_results = {}

# Install rubygems-update, so 'gem update --system' in cruise_config.rb auto-installs it on next build.
# This is how you can auto-update rubygems without logging in to CI system
build_results[:geminstaller] = system "sudo gem install rubygems-update -v 1.3.5 --no-ri --no-rdoc"

# Install required version of bundler.
build_results[:geminstaller] = system "sudo gem install bundler -v 0.9.0.pre3 --prerelease --no-ri --no-rdoc"

cd root_dir do
  puts
  puts "[CruiseControl] Bundling RubyGems"
  puts
  build_results[:bundle] = system 'env CI=1 sudo bundle install'
end

cd "#{root_dir}/activesupport" do
  puts
  puts "[CruiseControl] Building ActiveSupport"
  puts
  build_results[:activesupport] = rake 'test'
  build_results[:activesupport_isolated] = rake 'test:isolated'
end

cd "#{root_dir}/railties" do
  puts
  puts "[CruiseControl] Building RailTies"
  puts
  build_results[:railties] = rake 'test'
end

cd "#{root_dir}/actionpack" do
  puts
  puts "[CruiseControl] Building ActionPack"
  puts
  build_results[:actionpack] = rake 'test'
  build_results[:actionpack_isolated] = rake 'test:isolated'
end

cd "#{root_dir}/actionmailer" do
  puts
  puts "[CruiseControl] Building ActionMailer"
  puts
  build_results[:actionmailer] = rake 'test'
end

cd "#{root_dir}/activemodel" do
  puts
  puts "[CruiseControl] Building ActiveModel"
  puts
  build_results[:activemodel] = rake 'test'
end

rm_f "#{root_dir}/activeresource/debug.log"
cd "#{root_dir}/activeresource" do
  puts
  puts "[CruiseControl] Building ActiveResource"
  puts
  build_results[:activeresource] = rake 'test'
end

rm_f "#{root_dir}/activerecord/debug.log"
cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building ActiveRecord with MySQL"
  puts
  build_results[:activerecord_mysql] = rake 'mysql:rebuild_databases', 'test_mysql'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building ActiveRecord with PostgreSQL"
  puts
  build_results[:activerecord_postgresql8] = rake 'postgresql:rebuild_databases', 'test_postgresql'
end

cd "#{root_dir}/activerecord" do
  puts
  puts "[CruiseControl] Building ActiveRecord with SQLite 3"
  puts
  build_results[:activerecord_sqlite3] = rake 'test_sqlite3'
end


puts
puts "[CruiseControl] Build environment:"
puts "[CruiseControl]   #{`cat /etc/issue`}"
puts "[CruiseControl]   #{`uname -a`}"
puts "[CruiseControl]   #{`ruby -v`}"
puts "[CruiseControl]   #{`mysql --version`}"
puts "[CruiseControl]   #{`pg_config --version`}"
puts "[CruiseControl]   SQLite3: #{`sqlite3 -version`}"
`gem env`.each_line {|line| print "[CruiseControl]   #{line}"}
puts "[CruiseControl]   Bundled gems:"
`gem bundle --list`.each_line {|line| print "[CruiseControl]     #{line}"}
puts "[CruiseControl]   Local gems:"
`gem list`.each_line {|line| print "[CruiseControl]     #{line}"}

failures = build_results.select { |key, value| value == false }

if failures.empty?
  puts
  puts "[CruiseControl] Rails build finished sucessfully"
  exit(0)
else
  puts
  puts "[CruiseControl] Rails build FAILED"
  puts "[CruiseControl] Failed components: #{failures.map { |component| component.first }.join(', ')}"
  exit(-1)
end

