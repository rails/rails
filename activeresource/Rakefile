gem 'rdoc', '= 2.2'
require 'rdoc'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'

desc "Default Task"
task :default => [ :test ]

# Run the unit tests

Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
}

namespace :test do
  task :isolated do
    ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
    activesupport_path = "#{File.dirname(__FILE__)}/../activesupport/lib"
    Dir.glob("test/**/*_test.rb").all? do |file|
      system(ruby, '-w', "-Ilib:test:#{activesupport_path}", file)
    end or raise "Failures"
  end
end

# Generate the RDoc documentation

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Active Resource -- Object-oriented REST services"
  rdoc.options << '--line-numbers' << '--inline-source' << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : '../doc/template/horo'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/activeresource.rb')
}


spec = eval(File.read('activeresource.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  for file_name in FileList["lib/active_resource/**/*.rb"]
    next if file_name =~ /vendor/
    f = File.open(file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end


# Publishing ------------------------------------------------------

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("rails@api.rubyonrails.org", "public_html/ar", "doc").upload
end
