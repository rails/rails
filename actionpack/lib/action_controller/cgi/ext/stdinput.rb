require 'cgi'

module ActionController
  module CgiExt
    # Publicize the CGI's internal input stream so we can lazy-read
    # request.body. Make it writable so we don't have to play $stdin games.
    module Stdinput
      def self.included(base)
        base.class_eval do
          remove_method :stdinput
          attr_accessor :stdinput
        end

        base.alias_method_chain :initialize, :stdinput
      end

      def initialize_with_stdinput(type = nil, stdinput = $stdin)
        @stdinput = stdinput
        @stdinput.set_encoding(Encoding::BINARY) if @stdinput.respond_to?(:set_encoding)
        initialize_without_stdinput(type || 'query')
      end
    end
  end
end
