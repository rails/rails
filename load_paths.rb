begin
  require File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  begin
    require 'rubygems' unless defined? Gem
    require 'bundler'
    Bundler.setup
  rescue LoadError
    module Bundler
      def self.require(*args, &block); end
      def self.method_missing(*args, &block); end
    end

    %w(
      actionmailer
      actionpack
      activemodel
      activerecord
      activeresource
      activesupport
      railties
    ).each do |framework|
      $:.unshift File.expand_path("../#{framework}/lib", __FILE__)
    end
  end
end
