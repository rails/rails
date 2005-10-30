desc "Lock this application to the current gems (by unpacking them into vendor/rails)"
task :freeze_gems do
  rm_rf   "vendor/rails"
  mkdir_p "vendor/rails"
  
  for gem in %w( actionpack activerecord actionmailer activesupport actionwebservice )
    system "cd vendor/rails; gem unpack #{gem}"
    FileUtils.mv(Dir.glob("vendor/rails/#{gem}*").first, "vendor/rails/#{gem}")
  end
  
  system "cd vendor/rails; gem unpack rails"
  FileUtils.mv(Dir.glob("vendor/rails/rails*").first, "vendor/rails/railties")
end

desc "Lock this application to the Edge Rails (by exporting from Subversion).  Defaults to svn HEAD; do 'rake freeze_edge REVISION=1234' to lock to a specific revision."
task :freeze_edge do
  $verbose = false
  `svn --version`
  unless $?.success?
    $stderr.puts "ERROR: Must have subversion (svn) available in the PATH to lock this application to Edge Rails"
    exit 1
  end

  rm_rf   "vendor/rails"
  mkdir_p "vendor/rails"

  revision_switch = ENV['REVISION'] ? " -r #{ENV['REVISION']}" : ''
  for framework in %w( railties actionpack activerecord actionmailer activesupport actionwebservice )
    mkdir_p "vendor/rails/#{framework}"
    system  "svn export http://dev.rubyonrails.org/svn/rails/trunk/#{framework}/lib vendor/rails/#{framework}/lib #{revision_switch}"
  end
end

desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
task :unfreeze_rails do
  rm_rf "vendor/rails"
end
