# frozen_string_literal: true

OpenSSL::Digest
OpenSSL::Digest::SHA1
OpenSSL::Digest::SHA256.new
OpenSSL::Digest::MD5.hexdigest(["test", "digest"]).join(":")
some_method(OpenSSL::Digest::SHA256.new)
ActionController::HttpAuthentication::Digest::ControllerMethods
