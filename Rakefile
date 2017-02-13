# frozen_string_literal: true
require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

desc "Default Task"
task default: [ :test ]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
end

specname = "arel.gemspec"
deps = `git ls-files`.split("\n") - [specname]

file specname => deps do
  files = ["History.txt", "MIT-LICENSE.txt", "README.md"] + `git ls-files -- lib`.split("\n")

  require 'erb'

  File.open specname, 'w:utf-8' do |f|
    f.write ERB.new(File.read("#{specname}.erb")).result(binding)
  end
end
