module Rails
  module Generators
    class EnvironmentGenerator < Base # :nodoc:
      argument :name, type: :string
      class_option :from, type: :string, default: "development", desc: "Choose which environment to base the new environment off of"
      class_option :copy, type: :boolean, default: false, desc: "Copy the existing environment file instead of requiring it"
                              
      def add_database_yml_entry
        adapter = ActiveRecord::Base.connection_config[:adapter]
        append_template "config/database.yml", "databases/#{adapter}.yml"
      end
            
      def add_environment_file
        if copy? 
          create_file "config/environments/#{name}.rb", File.read(Rails.root.join("config", "environments", "#{options[:from]}.rb"))
        else
          template "inherited_environment.rb", "config/environments/#{name}.rb"
        end
      end
      
      def add_secrets_yml_entry
        append_template "config/secrets.yml", "secrets.yml"
      end
      
      
      protected
      
      def append_template(dst, template_name)
        source  = File.expand_path(find_in_source_paths(template_name))
        content = ERB.new(::File.binread(source), nil, "-", "@output_buffer").result(instance_eval("binding"))
        append_file dst, content      
      end
      
      
      def copy?
        options[:copy]
      end
      
    end
  end
end
