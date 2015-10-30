namespace :rails do
  def parse_args
    options = {}
    o = OptionParser.new
    o.banner = "Usage: rake rails:update -- [options]"
    o.on("-o", "--skip-active-record") { options[:skip_active_record] = true }
    args = o.order!(ARGV) {}
    o.parse!(args)
    options
  end

  desc "Update configs and some other initially generated files (or use just update:configs or update:bin)"
  task :update do
    Rake::Task['rails:update:configs'].invoke(parse_args)
    Rake::Task['rails:update:bin'].invoke
  end

  desc "Applies the template supplied by LOCATION=(/path/to/template) or URL"
  task template: :environment do
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
    class RailsUpdate
      def self.invoke_from_app_generator(method, options)
        app_generator(options).send(method)
      end

      def self.app_generator(options)
        @app_generator ||= begin
          require 'rails/generators'
          require 'rails/generators/rails/app/app_generator'
          gen = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }.merge(options),
            destination_root: Rails.root
          File.exist?(Rails.root.join("config", "application.rb")) ?
            gen.send(:app_const) : gen.send(:valid_const?)
          gen
        end
      end
    end

    # desc "Update config/boot.rb from your current rails install"
    task :configs, [:options] do |t, update_args|
      skip_options = (update_args[:options] || {}).merge(parse_args)

      RailsUpdate.invoke_from_app_generator :create_boot_file, skip_options 
      RailsUpdate.invoke_from_app_generator :update_config_files, skip_options 
    end

    # desc "Adds new executables to the application bin/ directory"
    task :bin do
      RailsUpdate.invoke_from_app_generator :create_bin_files, {} 
    end
  end
end
