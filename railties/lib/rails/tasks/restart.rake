desc "Restart app by touching tmp/restart.txt"
task :restart do
  ActiveSupport::Deprecation.warn("`rake restart` is deprecated and will be removed in a future Rails version. Please use `rails restart` instead.")
  FileUtils.mkdir_p('tmp')
  FileUtils.touch('tmp/restart.txt')
end
