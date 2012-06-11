namespace :rails do
  desc "Update configs and some other initially generated files (or use just update:configs, update:scripts, or update:application_controller)"
  task :update => [ "update:configs", "update:scripts", "update:application_controller" ]

  desc "Applies the template supplied by LOCATION=(/path/to/template) or URL"
  task :template do
    template = ENV["LOCATION"]
    raise "No LOCATION value given. Please set LOCATION either as path to a file or a URL" if template.blank?
    template = File.expand_path(template) if template !~ %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://}
    require 'rails/generators'
    require 'rails/generators/rails/app/app_generator'
    generator = Rails::Generators::AppGenerator.new [Rails.root], {}, :destination_root => Rails.root
    generator.apply template, :verbose => false
  end

  namespace :templates do
    # desc "Copy all the templates from rails to the application directory for customization. Already existing local copies will be overwritten"
    task :copy do
      generators_lib = File.expand_path("../../generators", __FILE__)
      project_templates = "#{Rails.root}/lib/templates"

      default_templates = { "erb"   => %w{controller mailer scaffold},
                            "rails" => %w{controller helper scaffold_controller assets} }

      default_templates.each do |type, names|
        local_template_type_dir = File.join(project_templates, type)
        FileUtils.mkdir_p local_template_type_dir

        names.each do |name|
          dst_name = File.join(local_template_type_dir, name)
          src_name = File.join(generators_lib, type, name, "templates")
          FileUtils.cp_r src_name, dst_name
        end
      end
     end
  end

  namespace :update do
    def invoke_from_app_generator(method)
      app_generator.send(method)
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

    # desc "Update config/boot.rb from your current rails install"
    task :configs do
      invoke_from_app_generator :create_boot_file
      invoke_from_app_generator :create_config_files
    end

    # desc "Adds new scripts to the application script/ directory"
    task :scripts do
      invoke_from_app_generator :create_script_files
    end

    # desc "Rename application.rb to application_controller.rb"
    task :application_controller do
      old_style = Rails.root + '/app/controllers/application.rb'
      new_style = Rails.root + '/app/controllers/application_controller.rb'
      if File.exists?(old_style) && !File.exists?(new_style)
        FileUtils.mv(old_style, new_style)
        puts "#{old_style} has been renamed to #{new_style}, update your SCM as necessary"
      end
    end
  end
end
