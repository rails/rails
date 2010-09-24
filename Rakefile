require "rubygems"

begin
  require "spec/rake/spectask"
rescue LoadError
  desc "Run specs"
  task(:spec) { $stderr.puts '`gem install rspec` to run specs' }
else
  Spec::Rake::SpecTask.new do |t|
    t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
    t.libs << "spec"
    t.warning = true
    t.spec_files = FileList['spec/**/*_spec.rb']
  end

  desc "Default task is to run specs"
  task :default => :spec
end
