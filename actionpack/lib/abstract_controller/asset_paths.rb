module AbstractController
  module AssetPaths
    extend ActiveSupport::Concern

    included do
      config_accessor :assets_dir, :javascripts_dir, :stylesheets_dir
    end
  end
end