require 'thread'
require 'active_support/core_ext/file'
require 'active_support/core_ext/module/attribute_accessors'

module ActionView
  # = Action View Asset Cache ID Helpers
  #
  # Rails appends asset's timestamps to public asset paths. This allows
  # you to set a cache-expiration date for the asset far into the future, but
  # still be able to instantly invalidate it by simply updating the file (and
  # hence updating the timestamp, which then updates the URL as the timestamp
  # is part of that, which in turn busts the cache).
  #
  # It's the responsibility of the web server you use to set the far-future
  # expiration date on cache assets that you need to take advantage of this
  # feature. Here's an example for Apache:
  #
  #   # Asset Expiration
  #   ExpiresActive On
  #   <FilesMatch "\.(ico|gif|jpe?g|png|js|css)$">
  #     ExpiresDefault "access plus 1 year"
  #   </FilesMatch>
  #
  # Also note that in order for this to work, all your application servers must
  # return the same timestamps. This means that they must have their clocks
  # synchronized. If one of them drifts out of sync, you'll see different
  # timestamps at random and the cache won't work. In that case the browser
  # will request the same assets over and over again even thought they didn't
  # change. You can use something like Live HTTP Headers for Firefox to verify
  # that the cache is indeed working.
  #
  # This strategy works well enough for most server setups and requires the
  # least configuration, but if you deploy several application servers at
  # different times - say to handle a temporary spike in load - then the
  # asset time stamps will be out of sync. In a setup like this you may want
  # to set the way that asset paths are generated yourself.
  #
  # Altering the asset paths that Rails generates can be done in two ways.
  # The easiest is to define the RAILS_ASSET_ID environment variable. The
  # contents of this variable will always be used in preference to
  # calculated timestamps. A more complex but flexible way is to set
  # <tt>ActionController::Base.config.asset_path</tt> to a proc
  # that takes the unmodified asset path and returns the path needed for
  # your asset caching to work. Typically you'd do something like this in
  # <tt>config/environments/production.rb</tt>:
  #
  #   # Normally you'd calculate RELEASE_NUMBER at startup.
  #   RELEASE_NUMBER = 12345
  #   config.action_controller.asset_path = proc { |asset_path|
  #     "/release-#{RELEASE_NUMBER}#{asset_path}"
  #   }
  #
  # This example would cause the following behavior on all servers no
  # matter when they were deployed:
  #
  #   image_tag("rails.png")
  #   # => <img alt="Rails" src="/release-12345/images/rails.png" />
  #   stylesheet_link_tag("application")
  #   # => <link href="/release-12345/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" />
  #
  # Changing the asset_path does require that your web servers have
  # knowledge of the asset template paths that you rewrite to so it's not
  # suitable for out-of-the-box use. To use the example given above you
  # could use something like this in your Apache VirtualHost configuration:
  #
  #   <LocationMatch "^/release-\d+/(images|javascripts|stylesheets)/.*$">
  #     # Some browsers still send conditional-GET requests if there's a
  #     # Last-Modified header or an ETag header even if they haven't
  #     # reached the expiry date sent in the Expires header.
  #     Header unset Last-Modified
  #     Header unset ETag
  #     FileETag None
  #
  #     # Assets requested using a cache-busting filename should be served
  #     # only once and then cached for a really long time. The HTTP/1.1
  #     # spec frowns on hugely-long expiration times though and suggests
  #     # that assets which never expire be served with an expiration date
  #     # 1 year from access.
  #     ExpiresActive On
  #     ExpiresDefault "access plus 1 year"
  #   </LocationMatch>
  #
  #   # We use cached-busting location names with the far-future expires
  #   # headers to ensure that if a file does change it can force a new
  #   # request. The actual asset filenames are still the same though so we
  #   # need to rewrite the location from the cache-busting location to the
  #   # real asset location so that we can serve it.
  #   RewriteEngine On
  #   RewriteRule ^/release-\d+/(images|javascripts|stylesheets)/(.*)$ /$1/$2 [L]
  #
  module Helpers #:nodoc:
    module AssetIdHelper
      # You can enable or disable the asset tag ids cache.
      # With the cache enabled, the asset tag helper methods will make fewer
      # expensive file system calls (the default implementation checks the file
      # system timestamp). However this prevents you from modifying any asset
      # files while the server is running.
      #
      #   ActionView::Helpers::AssetIdHelper.cache_asset_ids = false
      mattr_accessor :cache_asset_ids

      # Add or change an asset id in the asset id cache. This can be used
      # for SASS on Heroku.
      # :api: public
      def add_to_asset_ids_cache(source, asset_id)
        self.asset_ids_cache_guard.synchronize do
          self.asset_ids_cache[source] = asset_id
        end
      end

      mattr_accessor :asset_ids_cache
      self.asset_ids_cache = {}

      mattr_accessor :asset_ids_cache_guard
      self.asset_ids_cache_guard = Mutex.new

      # Use the RAILS_ASSET_ID environment variable or the source's
      # modification time as its cache-busting asset id.
      def rails_asset_id(source)
        if asset_id = ENV["RAILS_ASSET_ID"]
          asset_id
        else
          if self.cache_asset_ids && (asset_id = self.asset_ids_cache[source])
            asset_id
          else
            path = File.join(config.assets_dir, source)
            asset_id = File.exist?(path) ? File.mtime(path).to_i.to_s : ''

            if self.cache_asset_ids
              add_to_asset_ids_cache(source, asset_id)
            end

            asset_id
          end
        end
      end

      # Override +compute_asset_path+ to add asset id query strings to
      # generated urls. See +compute_asset_path+ in AssetUrlHelper.
      def compute_asset_path(source, options = {})
        source = super(source, options)
        path = config.asset_path

        if path && path.respond_to?(:call)
          path.call(source)
        elsif path && path.is_a?(String)
          path % [source]
        elsif asset_id = rails_asset_id(source)
          asset_id.empty? ? source : "#{source}?#{asset_id}"
        end
      end
    end
  end
end
