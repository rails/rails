namespace :rails do
  namespace :freeze do
    desc "Lock this application to the current gems (by unpacking them into vendor/rails)"
    task :gems do
      deps = %w(actionpack activerecord actionmailer activesupport activeresource)
      require 'rubygems'
      require 'rubygems/gem_runner'

      rails = (version = ENV['VERSION']) ?
        Gem.cache.find_name('rails', "= #{version}").first :
        Gem.cache.find_name('rails').sort_by { |g| g.version }.last

      version ||= rails.version

      unless rails
        puts "No rails gem #{version} is installed.  Do 'gem list rails' to see what you have available."
        exit
      end

      puts "Freezing to the gems for Rails #{rails.version}"
      rm_rf   "vendor/rails"
      mkdir_p "vendor/rails"

      begin
        chdir("vendor/rails") do
          rails.dependencies.select { |g| deps.include? g.name }.each do |g|
            Gem::GemRunner.new.run(["unpack", g.name, "--version", g.version_requirements.to_s])
            mv(Dir.glob("#{g.name}*").first, g.name)
          end

          Gem::GemRunner.new.run(["unpack", "rails", "--version", "=#{version}"])
          FileUtils.mv(Dir.glob("rails*").first, "railties")
        end
      rescue Exception
        rm_rf "vendor/rails"
        raise
      end
    end

    desc 'Lock to latest Edge Rails, for a specific release use RELEASE=1.2.0'
    task :edge do
      require 'open-uri'
      version = ENV["RELEASE"] || "edge"
      target  = "rails_#{version}.zip"
      commits = "http://github.com/api/v1/yaml/rails/rails/commits/master"
      url     = "http://dev.rubyonrails.org/archives/#{target}"

      chdir 'vendor' do
        latest_revision = YAML.load(open(commits))["commits"].first["id"]

        puts "Downloading Rails from #{url}"
        File.open('rails.zip', 'wb') do |dst|
          open url do |src|
            while chunk = src.read(4096)
              dst << chunk
            end
          end
        end

        puts 'Unpacking Rails'
        rm_rf 'rails'
        `unzip rails.zip`
        %w(rails.zip rails/Rakefile rails/cleanlogs.sh rails/pushgems.rb rails/release.rb).each do |goner|
          rm_f goner
        end

        touch "rails/REVISION_#{latest_revision}"
      end

      puts 'Updating current scripts, javascripts, and configuration settings'
      Rake::Task['rails:update'].invoke
    end
  end

  desc "Unlock this application from freeze of gems or edge and return to a fluid use of system gems"
  task :unfreeze do
    rm_rf "vendor/rails"
  end

  desc "Update both configs, scripts and public/javascripts from Rails"
  task :update => [ "update:configs", "update:javascripts", "update:scripts", "update:application_controller" ]

  desc "Applies the template supplied by LOCATION=/path/to/template"
  task :template do
    template = ENV["LOCATION"]
    template = File.expand_path(template) if template !~ %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://}

    require 'generators'
    generator = Rails::Generators::App.new [ RAILS_ROOT ], {}, :destination_root => RAILS_ROOT
    generator.apply template, :verbose => false
  end

  namespace :update do
    def invoke_from_app_generator(method)
      require 'generators'
      require 'generators/rails/app/app_generator'

      generator = Rails::Generators::AppGenerator.new ["rails"], { :with_dispatchers => true },
                                                      :destination_root => RAILS_ROOT
      generator.invoke(method)
    end

    desc "Update config/boot.rb from your current rails install"
    task :configs do
      invoke_from_app_generator :create_boot_file
    end

    desc "Update Prototype javascripts from your current rails install"
    task :javascripts do
      invoke_from_app_generator :create_prototype_files
    end

    desc "Generate dispatcher files in RAILS_ROOT/public"
    task :generate_dispatchers do
      invoke_from_app_generator :create_dispatch_files
    end

    desc "Add new scripts to the application script/ directory"
    task :scripts do
      invoke_from_app_generator :create_script_files
    end

    desc "Rename application.rb to application_controller.rb"
    task :application_controller do
      old_style = RAILS_ROOT + '/app/controllers/application.rb'
      new_style = RAILS_ROOT + '/app/controllers/application_controller.rb'
      if File.exists?(old_style) && !File.exists?(new_style)
        FileUtils.mv(old_style, new_style)
        puts "#{old_style} has been renamed to #{new_style}, update your SCM as necessary"
      end
    end
  end
end
