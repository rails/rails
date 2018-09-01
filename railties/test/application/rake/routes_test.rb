# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeRoutesTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation
      setup :build_app
      teardown :teardown_app

      test "`rake routes` outputs routes" do
        app_file "config/routes.rb", <<-RUBY
          Rails.application.routes.draw do
            get '/cart', to: 'cart#show'
          end
        RUBY

        assert_equal <<~MESSAGE, run_rake_routes
                   Prefix Verb URI Pattern                                                                              Controller#Action
                     cart GET  /cart(.:format)                                                                          cart#show
       rails_service_blob GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                               active_storage/blobs#show
rails_blob_representation GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations#show
       rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                              active_storage/disk#show
update_rails_disk_service PUT  /rails/active_storage/disk/:encoded_token(.:format)                                      active_storage/disk#update
     rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format)                                           active_storage/direct_uploads#create
        MESSAGE
      end

      test "`rake routes` outputs a deprecation warning" do
        add_to_env_config("development", "config.active_support.deprecation = :stderr")

        stderr = capture(:stderr) { run_rake_routes }
        assert_match(/DEPRECATION WARNING: Using `bin\/rake routes` is deprecated and will be removed in Rails 6.1/, stderr)
      end

      private
        def run_rake_routes
          Dir.chdir(app_path) { `bin/rake routes` }
        end
    end
  end
end
