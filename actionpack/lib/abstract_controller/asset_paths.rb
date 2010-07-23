module AbstractController
  module AssetPaths
    extend ActiveSupport::Concern

    included do
      config_accessor :asset_host, :assets_dir, :javascripts_dir, :stylesheets_dir
    end
  end
end