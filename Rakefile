require 'bundler'
Bundler::GemHelper.install_tasks

specname = "arel.gemspec"
deps = `git ls-files`.split("\n") - [specname]

file specname => deps do
  files       = `git ls-files`.split("\n") - ["#{specname}.erb"]

  require 'erb'

  File.open specname, 'w:utf-8' do |f|
    f.write ERB.new(File.read("#{specname}.erb")).result(binding)
  end
end
