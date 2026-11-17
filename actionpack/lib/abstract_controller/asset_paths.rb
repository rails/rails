# frozen_string_literal: true

module AbstractController
  module AssetPaths # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
    end

    Config.generate_accessors(self, :asset_host, :assets_dir, :javascripts_dir, :stylesheets_dir, :default_asset_host_protocol, :relative_url_root)
  end
end
