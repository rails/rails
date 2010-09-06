namespace :railties do
  desc "Create symlinks to railties public directories in application's public directory."
  task :create_symlinks => :environment do
    paths = Rails.application.config.static_asset_paths.dup
    app_public_path = Rails.application.config.paths.public.to_a.first

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
end
