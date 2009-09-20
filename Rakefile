require "rubygems"

begin
  require 'jeweler'
rescue LoadError
  desc "Install gem using sudo"
  task(:install) do
    $stderr.puts "Jeweler not available. `gem install jeweler` to install this gem"
  end
else
  Jeweler::Tasks.new do |s|
    s.name      = "arel"
    s.authors   = ["Bryan Helmkamp", "Nick Kallen"]
    s.email     = "bryan" + "@" + "brynary.com"
    s.homepage  = "http://github.com/brynary/arel"
    s.summary   = "Arel is a relational algebra engine for Ruby"
    # s.description  = "TODO"
    s.rubyforge_project = "arel"
    s.extra_rdoc_files = %w(README.markdown)

    s.add_dependency "activerecord", ">= 3.0pre"
    s.add_dependency "activesupport", ">= 3.0pre"
  end

  Jeweler::RubyforgeTasks.new
end

begin
  require "spec/rake/spectask"
rescue LoadError
  desc "Run specs"
  task(:spec) { $stderr.puts '`gem install rspec` to run specs' }
else
  desc "Run specs using RCov (uses mysql database adapter)"
  Spec::Rake::SpecTask.new(:coverage) do |t|
    t.spec_files =
      ["spec/connections/mysql_connection.rb"] +
      FileList['spec/**/*_spec.rb']

    t.rcov = true
    t.rcov_opts << '--exclude' << "spec,gems"
    t.rcov_opts << '--text-summary'
    t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
    t.rcov_opts << '--only-uncovered'
  end

  namespace :spec do
    for adapter in %w[mysql sqlite3 postgresql]
      desc "Run specs with the #{adapter} database adapter"
      Spec::Rake::SpecTask.new(adapter) do |t|
        t.libs << "#{File.dirname(__FILE__)}/vendor/rails/activerecord/lib"
        t.libs << "#{File.dirname(__FILE__)}/spec"
        t.spec_files =
          ["spec/connections/#{adapter}_connection.rb"] +
          ["spec/schemas/#{adapter}_schema.rb"] +
          FileList['spec/**/*_spec.rb']
      end
    end
  end

  desc "Run specs with mysql and sqlite3 database adapters (default)"
  task :spec => ["check_dependencies", "spec:sqlite3", "spec:mysql", "spec:postgresql"]

  desc "Default task is to run specs"
  task :default => :spec
end

desc 'Removes trailing whitespace'
task :whitespace do
  sh %{find . -name '*.rb' -exec sed -i '' 's/ *$//g' {} \\;}
end
