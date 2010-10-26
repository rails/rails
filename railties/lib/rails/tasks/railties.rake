namespace :railties do
  namespace :install do
    # desc "Copies missing assets from Railties (e.g. plugins, engines). You can specify Railties to use with FROM=railtie1,railtie2"
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
