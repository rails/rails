require 'rubygems'
require 'spec/rake/spectask'

spec_file_list = FileList['spec/**/*_spec.rb']

desc "Run specs using RCov (uses mysql database adapter)"
Spec::Rake::SpecTask.new(:coverage) do |t|
  t.spec_files =
    ["spec/connections/mysql_connection.rb"] +
    spec_file_list

  t.rcov = true
  t.rcov_opts << '--exclude' << "spec,gems"
  t.rcov_opts << '--text-summary'
  t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
  t.rcov_opts << '--only-uncovered'
end

namespace :spec do
  for adapter in %w[mysql sqlite3]
    desc "Run specs with the #{adapter} database adapter"
    Spec::Rake::SpecTask.new(adapter) do |t|
      t.spec_files =
        ["spec/connections/#{adapter}_connection.rb"] +
        ["spec/schemas/#{adapter}_schema.rb"] +
        spec_file_list
    end
  end
end

desc "Run specs with mysql and sqlite3 database adapters (default)"
task :spec => ["spec:sqlite3", "spec:mysql"]

desc "Default task is to run specs"
task :default => :spec

desc 'Removes trailing whitespace'
task :whitespace do
  sh %{find . -name '*.rb' -exec sed -i '' 's/ *$//g' {} \\;}
end
