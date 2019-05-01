# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "app/controllers"
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = true
end

if ENV["encrypted_0fb9444d0374_key"] && ENV["encrypted_0fb9444d0374_iv"]
  file "test/service/configurations.yml" do
    system "openssl aes-256-cbc -K $encrypted_0fb9444d0374_key -iv $encrypted_0fb9444d0374_iv -in test/service/configurations.yml.enc -out test/service/configurations.yml -d"
  end

  task test: "test/service/configurations.yml"
end

task :package

task default: :test
