namespace :railties do
  # desc "Create symlinks to railties public directories in application's public directory."
  task :create_symlinks => :environment do
    paths = Rails.application.config.static_asset_paths.dup
    app_public_path = Rails.application.paths["public"].first

    paths.each do |mount_path, path|
      symlink_path = File.join(app_public_path, mount_path)
      if File.exist?(symlink_path)
        File.symlink?(symlink_path) ? FileUtils.rm(symlink_path) : next
      end

      next unless File.exist?(path)

      File.symlink(path, symlink_path)

      puts "Created symlink #{symlink_path} -> #{path}"
    end
  end

  namespace :install do
    desc "Copies missing assets from Railties (e.g. plugins, engines). You can specify Railties to use with FROM=railtie1,railtie2"
    task :assets => :rails_env do
      require 'rails/generators/base'
      Rails.application.initialize!

      to_load = ENV["FROM"].blank? ? :all : ENV["FROM"].split(",").map {|n| n.strip }
      app_public_path = Rails.application.paths["public"].first

      Rails.application.railties.all do |railtie|
        next unless to_load == :all || to_load.include?(railtie.railtie_name)

        if railtie.respond_to?(:paths) && (path = railtie.paths["public"].first) &&
           (assets_dir = railtie.config.compiled_asset_path) && File.exist?(path)

          Rails::Generators::Base.source_root(path)
          copier = Rails::Generators::Base.new
          Dir[File.join(path, "**/*")].each do |file|
            relative = file.gsub(/^#{path}\//, '')
            if File.file?(file)
              copier.copy_file relative, File.join(app_public_path, assets_dir, relative)
            end
          end
        end
      end
    end
  end
end
