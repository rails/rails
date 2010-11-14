require 'thread'
require 'cgi'
require 'action_view/helpers/url_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/asset_tag_helpers/base_asset_helpers'
require 'action_view/helpers/asset_tag_helpers/javascript_tag_helpers'
require 'action_view/helpers/asset_tag_helpers/stylesheet_tag_helpers'
require 'action_view/helpers/asset_tag_helpers/asset_id_caching'
require 'active_support/core_ext/file'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/output_safety'

module ActionView
  # = Action View Asset Tag Helpers
  module Helpers #:nodoc:
    # This module provides methods for generating HTML that links views to assets such
    # as images, javascripts, stylesheets, and feeds. These methods do not verify
    # the assets exist before linking to them:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # === Using asset hosts
    #
    # By default, Rails links to these assets on the current host in the public
    # folder, but you can direct Rails to link to assets from a dedicated asset
    # server by setting ActionController::Base.asset_host in the application
    # configuration, typically in <tt>config/environments/production.rb</tt>.
    # For example, you'd define <tt>assets.example.com</tt> to be your asset
    # host this way:
    #
    #   ActionController::Base.asset_host = "assets.example.com"
    #
    # Helpers take that into account:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # Browsers typically open at most two simultaneous connections to a single
    # host, which means your assets often have to wait for other assets to finish
    # downloading. You can alleviate this by using a <tt>%d</tt> wildcard in the
    # +asset_host+. For example, "assets%d.example.com". If that wildcard is
    # present Rails distributes asset requests among the corresponding four hosts
    # "assets0.example.com", ..., "assets3.example.com". With this trick browsers
    # will open eight simultaneous connections rather than two.
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets0.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # To do this, you can either setup four actual hosts, or you can use wildcard
    # DNS to CNAME the wildcard to a single asset host. You can read more about
    # setting up your DNS CNAME records from your ISP.
    #
    # Note: This is purely a browser performance optimization and is not meant
    # for server load balancing. See http://www.die.net/musings/page_load_time/
    # for background.
    #
    # Alternatively, you can exert more control over the asset host by setting
    # +asset_host+ to a proc like this:
    #
    #   ActionController::Base.asset_host = Proc.new { |source|
    #     "http://assets#{source.hash % 2 + 1}.example.com"
    #   }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets1.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # The example above generates "http://assets1.example.com" and
    # "http://assets2.example.com". This option is useful for example if
    # you need fewer/more than four hosts, custom host names, etc.
    #
    # As you see the proc takes a +source+ parameter. That's a string with the
    # absolute path of the asset with any extensions and timestamps in place,
    # for example "/images/rails.png?1230601161".
    #
    #    ActionController::Base.asset_host = Proc.new { |source|
    #      if source.starts_with?('/images')
    #        "http://images.example.com"
    #      else
    #        "http://assets.example.com"
    #      end
    #    }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://images.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # Alternatively you may ask for a second parameter +request+. That one is
    # particularly useful for serving assets from an SSL-protected page. The
    # example proc below disables asset hosting for HTTPS connections, while
    # still sending assets for plain HTTP requests from asset hosts. If you don't
    # have SSL certificates for each of the asset hosts this technique allows you
    # to avoid warnings in the client about mixed media.
    #
    #   ActionController::Base.asset_host = Proc.new { |source, request|
    #     if request.ssl?
    #       "#{request.protocol}#{request.host_with_port}"
    #     else
    #       "#{request.protocol}assets.example.com"
    #     end
    #   }
    #
    # You can also implement a custom asset host object that responds to +call+
    # and takes either one or two parameters just like the proc.
    #
    #   config.action_controller.asset_host = AssetHostingWithMinimumSsl.new(
    #     "http://asset%d.example.com", "https://asset1.example.com"
    #   )
    #
    # === Customizing the asset path
    #
    # By default, Rails appends asset's timestamps to all asset paths. This allows
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
    # This example would cause the following behaviour on all servers no
    # matter when they were deployed:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/release-12345/images/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/release-12345/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
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
    module AssetTagHelper
      include BaseAssetHelpers
      include JavascriptTagHelpers
      include StylesheetTagHelpers
      include AssetIdCaching
    end
  end
end
