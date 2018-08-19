# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Specify a serializer for the signed and encrypted cookie jars.
# Valid options are :json, :marshal, and :hybrid.
Rails.application.config.action_dispatch.cookies_serializer = :json

# Specify the SameSite level protection for the cookies
# Valid options are :no_protection, :lax, and :strict.
Rails.application.config.action_dispatch.cookies_same_site_protection = :no_protection
