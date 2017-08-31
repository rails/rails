# frozen_string_literal: true

require "rake/testtask"

test_files = Dir.glob("test/**/*_test.rb")

desc "Default Task"
task default: :test

task :package

# Run the unit tests
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = test_files

  t.warning = true
  t.verbose = true
  t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
end

namespace :test do
  task :isolated do
    test_files.all? do |file|
      sh(Gem.ruby, "-w", "-Ilib:test", file)
    end || raise("Failures")
  end
end

task :lines do
  load File.expand_path("..", __dir__) + "/tools/line_statistics"
  files = FileList["lib/**/*.rb"]
  CodeTools::LineStatistics.new(files).print_loc
end

rule ".rb" => ".y" do |t|
  sh "racc -l -o #{t.name} #{t.source}"
end

task compile: "lib/action_dispatch/journey/parser.rb"
