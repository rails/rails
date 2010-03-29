namespace :rails do
  namespace :freeze do
    desc "The rails:freeze:gems is deprecated, please use bundle install instead"
    task :gems do
      abort "The rails:freeze:gems is deprecated, please use bundle install instead"
    end

    desc 'The freeze:edge command has been deprecated, specify the path setting in your app Gemfile instead and bundle install'
    task :edge do
      abort 'The freeze:edge command has been deprecated, specify the path setting in your app Gemfile instead and bundle install'
    end
  end

  desc 'The unfreeze command has been deprecated, please use bundler commands instead'
  task :unfreeze do
    abort 'The unfreeze command has been deprecated, please use bundler commands instead'
  end

  desc "Update both configs, scripts and public/javascripts from Rails"
  task :update => [ "update:configs", "update:javascripts", "update:scripts", "update:application_controller", "update:test_directory" ]

  desc "Applies the template supplied by LOCATION=/path/to/template"
  task :template do
    template = ENV["LOCATION"]
    template = File.expand_path(template) if template !~ %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://}

    require 'rails/generators'
    require 'rails/generators/rails/app/app_generator'
    generator = Rails::Generators::AppGenerator.new [ Rails.root ], {}, :destination_root => Rails.root
    generator.apply template, :verbose => false
  end

  namespace :update do
    def invoke_from_app_generator(method)
      app_generator.invoke(method)
    end

    def app_generator
      @app_generator ||= begin
        require 'rails/generators'
        require 'rails/generators/rails/app/app_generator'
        gen = Rails::Generators::AppGenerator.new ["rails"], { :with_dispatchers => true },
                                                             :destination_root => Rails.root
        File.exists?(Rails.root.join("config", "application.rb")) ?
          gen.send(:app_const) : gen.send(:valid_app_const?)
        gen
      end
    end

    desc "Update config/boot.rb from your current rails install"
    task :configs do
      invoke_from_app_generator :create_boot_file
      invoke_from_app_generator :create_config_files
    end

    desc "Update Prototype javascripts from your current rails install"
    task :javascripts do
      invoke_from_app_generator :create_prototype_files
    end

    desc "Adds new scripts to the application script/ directory"
    task :scripts do
      invoke_from_app_generator :create_script_files
    end

    desc "Rename application.rb to application_controller.rb"
    task :application_controller do
      old_style = Rails.root + '/app/controllers/application.rb'
      new_style = Rails.root + '/app/controllers/application_controller.rb'
      if File.exists?(old_style) && !File.exists?(new_style)
        FileUtils.mv(old_style, new_style)
        puts "#{old_style} has been renamed to #{new_style}, update your SCM as necessary"
      end
    end

    desc "Move test directories to new locations"
    task :test_directory do
      if File.exists?(Rails.root.join('test'))
        FileUtils.mkdir(Rails.root.join('test/controllers')) unless File.exists?(Rails.root.join('test/controllers'))
        [Rails.root.join('test/functional'), Rails.root.join('test/integration')].each do |controller_test_dir|
          if File.exists?(controller_test_dir)
            puts "#{controller_test_dir} exists"
            FileUtils.mv(Dir["#{controller_test_dir}/**/*"], Rails.root.join('test/controllers'), :force => true)
            FileUtils.rm_rf(controller_test_dir)
          end
        end

        if File.exists?(Rails.root.join('test/unit/helpers'))
          FileUtils.mkdir(Rails.root.join('test/helpers')) unless File.exists?(Rails.root.join('test/helpers'))
          FileUtils.mv(Dir[Rails.root.join('test/unit/helpers/**/*')], Rails.root.join('test/helpers'), :force => true)
        else
          unless File.exists?(Rails.root.join('test/helpers'))
            FileUtils.mkdir(Rails.root.join('test/helpers'))
          end
        end
        
        if File.exists?(Rails.root.join('test/unit'))
          observer_tests = "#{Rails.root}/test/unit/**/*_observer_test.rb"
          unless observer_tests.empty?
            FileUtils.mkdir(Rails.root.join('test/observers')) unless File.exists?(Rails.root.join('test/observers'))
            FileUtils.mv(observer_tests, Rails.root.join('test/observers'), :force => true)
          end
          FileUtils.mkdir(Rails.root.join('test/models')) unless File.exists?(Rails.root.join('test/models'))
          FileUtils.mv(Dir[Rails.root.join('test/unit/*')], Rails.root.join('test/models'), :force => true)
          FileUtils.rm_rf(Rails.root.join('test/unit'))
        end
      end
      
      puts <<-TEST
      
      All test directories have been updated:
      
      test/functional                   ->      test/controllers
      test/functional                   ->      test/controllers
      test/unit/helpers                 ->      test/helpers
      test/unit/**/*_observer_test.rb   ->      test/observers
      test/unit                         ->      test/models
      TEST
    end
  end
end
