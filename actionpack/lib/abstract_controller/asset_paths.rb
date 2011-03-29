module AbstractController
  module AssetPaths
    extend ActiveSupport::Concern

    included do
      config_accessor :asset_host, :asset_path, :assets_dir, :javascripts_dir, :stylesheets_dir, :use_sprockets
    end
  end
end
