module AbstractController
  module AssetPaths
    extend ActiveSupport::Concern

    included do
      config_accessor :asset_host, :asset_path, :assets_dir, :javascripts_dir,
        :stylesheets_dir, :default_asset_host_protocol, :relative_url_root
    end
  end
end
