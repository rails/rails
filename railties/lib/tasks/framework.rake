namespace :rails do
  namespace :freeze do
    desc "Lock this application to the current gems (by unpacking them into vendor/rails)"
    task :gems do
      deps = %w(actionpack activerecord actionmailer activesupport actionwebservice)
      require 'rubygems'

      rails = if version = ENV['VERSION']
                Gem.cache.search('rails', "= #{version}").first
              else
                Gem.cache.search('rails').sort_by { |g| g.version }.last
              end
      version ||= rails.version

      unless rails
        puts "No rails gem #{version} is installed.  Do 'gem list rails' to see what you have available."
        exit
      end

      puts "Freezing to the gems for Rails #{rails.version}"
      rm_rf   "vendor/rails"
      mkdir_p "vendor/rails"

      rails.dependencies.select { |g| deps.include? g.name }.each do |g|
        system "cd vendor/rails; gem unpack -v '#{g.version_requirements}' #{g.name}; mv #{g.name}* #{g.name}"
      end
      system "cd vendor/rails; gem unpack -v '=#{version}' rails"
  
      FileUtils.mv(Dir.glob("vendor/rails/rails*").first, "vendor/rails/railties")
    end

    desc "Lock this application to latest Edge Rails. Lock a specific revision with REVISION=X"
    task :edge do
      $verbose = false
      `svn --version` rescue nil
      unless !$?.nil? && $?.success?
        $stderr.puts "ERROR: Must have subversion (svn) available in the PATH to lock this application to Edge Rails"
        exit 1
      end

      rm_rf   "vendor/rails"
      mkdir_p "vendor/rails"

      revision_switch = ENV['REVISION'] ? " -r #{ENV['REVISION']}" : ''
      
      for framework in %w( railties actionpack activerecord actionmailer activesupport actionwebservice )
        mkdir_p "vendor/rails/#{framework}"
        system  "svn export http://dev.rubyonrails.org/svn/rails/trunk/#{framework} vendor/rails/#{framework} #{revision_switch}"
      end
    end
  end

  desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
  task :unfreeze do
    rm_rf "vendor/rails"
  end

  desc "Update both scripts and public/javascripts from Rails"
  task :update => [ "update:scripts", "update:javascripts" ]

  namespace :update do
    desc "Add new scripts to the application script/ directory"
    task :scripts do
      local_base = "script"
      edge_base  = "#{File.dirname(__FILE__)}/../../bin"

      local = Dir["#{local_base}/**/*"].reject { |path| File.directory?(path) }
      edge  = Dir["#{edge_base}/**/*"].reject { |path| File.directory?(path) }
  
      edge.each do |script|
        base_name = script[(edge_base.length+1)..-1]
        next if base_name == "rails"
        next if local.detect { |path| base_name == path[(local_base.length+1)..-1] }
        if !File.directory?("#{local_base}/#{File.dirname(base_name)}")
          mkdir_p "#{local_base}/#{File.dirname(base_name)}"
        end
        install script, "#{local_base}/#{base_name}", :mode => 0755
      end
    end

    desc "Update your javascripts from your current rails install"
    task :javascripts do 
      require 'railties_path'  
      FileUtils.cp(Dir[RAILTIES_PATH + '/html/javascripts/*.js'], RAILS_ROOT + '/public/javascripts/')
    end
  end
end