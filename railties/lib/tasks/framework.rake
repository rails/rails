desc "Lock this application to the current gems (by unpacking them into vendor/rails)"
task :freeze_gems do
  rm_rf   "vendor/rails"
  mkdir_p "vendor/rails"
  
  for gem in %w( actionpack activerecord actionmailer activesupport actionwebservice )
    system "cd vendor/rails; gem unpack #{gem}"
    FileUtils.mv(Dir.glob("vendor/rails/#{gem}*").first, "vendor/rails/#{gem}")
  end
  
  FileUtils.mv(Dir.glob("vendor/rails/rails*").first, "vendor/rails/railties")
end

desc "Lock this application to the Edge Rails (by exporting from Subversion)"
task :freeze_edge do
  $stderr.close
  svn_available = `svn --version`.size > 0
  raise "Subversion is not installed" unless svn_available

  rm_rf   "vendor/rails"
  mkdir_p "vendor/rails"
  
  for framework in %w( railties actionpack activerecord actionmailer activesupport actionwebservice )
    mkdir_p "vendor/rails/#{framework}"
    system  "svn export http://dev.rubyonrails.org/svn/rails/trunk/#{framework}/lib vendor/rails/#{framework}/lib"
  end
end

desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
task :unfreeze_rails do
  rm_rf "vendor/rails"
end