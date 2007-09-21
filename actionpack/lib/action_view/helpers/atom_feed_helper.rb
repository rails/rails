# Adds easy defaults to writing Atom feeds with the Builder template engine (this does not work on ERb or any other
# template languages).
module ActionView
  module Helpers #:nodoc:
    module AtomFeedHelper
      # Full usage example:
      #
      #   config/routes.rb:
      #     ActionController::Routing::Routes.draw do |map|
      #       map.resources :posts
      #       map.root :controller => "posts"
      #     end
      #
      #   app/controllers/posts_controller.rb:
      #     class PostsController < ApplicationController::Base
      #       # GET /posts.html
      #       # GET /posts.atom
      #       def index
      #         @posts = Post.find(:all)
      #         
      #         respond_to do |format|
      #           format.html
      #           format.atom
      #         end
      #       end
      #     end
      #
      #   app/views/posts/index.atom.builder:
      #     atom_feed do |feed|
      #       feed.title("My great blog!")
      #       feed.updated((@posts.first.created_at))
      #     
      #       for post in @posts
      #         feed.entry(post) do |entry|
      #           entry.title(post.title)
      #           entry.content(post.body, :type => 'html')
      #     
      #           entry.author do |author|
      #             author.name("DHH")
      #           end
      #         end
      #       end
      #     end
      #
      # The options are for atom_feed are:
      #
      # * <tt>:language</tt>: Defaults to "en-US".
      # * <tt>:root_url</tt>: The HTML alternative that this feed is doubling for. Defaults to / on the current host.
      # * <tt>:url</tt>: The URL for this feed. Defaults to the current URL.
      #
      # atom_feed yields a AtomFeedBuilder instance.
      def atom_feed(options = {}, &block)
        xml = options[:xml] || eval("xml", block.binding)
        xml.instruct!

        xml.feed "xml:lang" => options[:language] || "en-US", "xmlns" => 'http://www.w3.org/2005/Atom' do
          xml.id("tag:#{request.host}:#{request.request_uri.split(".")[0].gsub("/", "")}")      
          xml.link(:rel => 'alternate', :type => 'text/html', :href => options[:root_url] || (request.protocol + request.host_with_port))

          if options[:url]
            xml.link(:rel => 'self', :type => 'application/atom+xml', :href => options[:url] || request.url)
          end

          yield AtomFeedBuilder.new(xml, self)
        end
      end


      class AtomFeedBuilder
        def initialize(xml, view)
          @xml, @view = xml, view
        end
        
        # Accepts a Date or Time object and inserts it in the proper format. If nil is passed, current time in UTC is used.
        def updated(date_or_time = nil)
          @xml.updated((date_or_time || Time.now.utc).xmlschema)
        end

        # Creates an entry tag for a specific record and prefills the id using class and id.
        #
        # Options:
        #
        # * <tt>:updated</tt>: Time of update. Defaults to the created_at attribute on the record if one such exists.
        # * <tt>:published</tt>: Time first published. Defaults to the updated_at attribute on the record if one such exists.
        # * <tt>:url</tt>: The URL for this entry. Defaults to the polymorphic_url for the record.
        def entry(record, options = {})
          @xml.entry do 
            @xml.id("tag:#{@view.request.host_with_port}:#{record.class}#{record.id}")

            if options[:published] || (record.respond_to?(:created_at) && record.created_at)
              @xml.published((options[:published] || record.created_at).xmlschema)
            end

            if options[:updated] || (record.respond_to?(:updated_at) && record.updated_at)
              @xml.updated((options[:updated] || record.updated_at).xmlschema)
            end

            @xml.link(:rel => 'alternate', :type => 'text/html', :href => options[:url] || @view.polymorphic_url(record))

            yield @xml
          end
        end

        private
          def method_missing(method, *arguments)
            @xml.__send__(method, *arguments)
          end
      end
    end
  end
end