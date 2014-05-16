namespace :rails do
  desc "Update configs and some other initially generated files (or use just update:configs or update:bin)"
  task update: [ "update:configs", "update:bin" ]

  desc "Applies the template supplied by LOCATION=(/path/to/template) or URL"
  task :template do
    template = ENV["LOCATION"]
    raise "No LOCATION value given. Please set LOCATION either as path to a file or a URL" if template.blank?
    template = File.expand_path(template) if template !~ %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://}
    require 'rails/generators'
    require 'rails/generators/rails/app/app_generator'
    generator = Rails::Generators::AppGenerator.new [Rails.root], {}, destination_root: Rails.root
    generator.apply template, verbose: false
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
        gen = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true },
                                                             destination_root: Rails.root
        File.exist?(Rails.root.join("config", "application.rb")) ?
          gen.send(:app_const) : gen.send(:valid_const?)
        gen
      end
    end

    # desc "Update config/boot.rb from your current rails install"
    task :configs do
      invoke_from_app_generator :create_boot_file
      invoke_from_app_generator :update_config_files
    end

    # desc "Adds new executables to the application bin/ directory"
    task :bin do
      invoke_from_app_generator :create_bin_files
    end
  end
end
