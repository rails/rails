require 'bundler/resolver/inspect'
require 'bundler/resolver/search'
require 'bundler/resolver/engine'
require 'bundler/resolver/stack'
require 'bundler/resolver/state'

module Bundler
  module Resolver
    def self.resolve(deps, source_index = Gem.source_index, logger = nil)
      unless logger
        logger = Logger.new($stderr)
        logger.datetime_format = ""
        logger.level = ENV["GEM_RESOLVER_DEBUG"] ? Logger::DEBUG : Logger::ERROR
      end

      Engine.resolve(deps, source_index, logger)
    end
  end
end