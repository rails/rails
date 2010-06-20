require 'rake/testtask'
require "rake/gempackagetask"
require "rake/clean"

task :default => [:test]

CLEAN << "pkg" << "doc" << "coverage" << ".yardoc"

Rake::TestTask.new(:test) do |t|
  t.pattern = "#{File.dirname(__FILE__)}/test/all.rb"
  t.verbose = true
end
Rake::Task['test'].comment = "Run all i18n tests"

Rake::GemPackageTask.new(eval(File.read("i18n.gemspec"))) { |pkg| }

begin
  require "yard"
  YARD::Rake::YardocTask.new do |t|
    t.options = ["--output-dir=doc"]
    t.options << "--files" << ["CHANGELOG.textile", "contributors.txt", "MIT-LICENSE"].join(",")
  end
rescue LoadError
end
