begin
  require File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  begin
    require 'rubygems'
    require 'bundler'
    Bundler.setup
  rescue LoadError
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
