# frozen_string_literal: true

# :markup: markdown

module AbstractController
  module AssetPaths # :nodoc:
    extend ActiveSupport::Concern

    included do
      singleton_class.delegate :asset_host, :asset_host=, :assets_dir, :assets_dir=, :javascripts_dir, :javascripts_dir=,
        :stylesheets_dir, :stylesheets_dir=, :default_asset_host_protocol, :default_asset_host_protocol=, :relative_url_root, :relative_url_root=, to: :config
      delegate :asset_host, :asset_host=, :assets_dir, :assets_dir=, :javascripts_dir, :javascripts_dir=,
        :stylesheets_dir, :stylesheets_dir=, :default_asset_host_protocol, :default_asset_host_protocol=, :relative_url_root, :relative_url_root=, to: :config
    end
  end
end
