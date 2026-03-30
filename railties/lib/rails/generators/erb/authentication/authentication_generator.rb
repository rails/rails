# frozen_string_literal: true

require "rails/generators/erb"

module Erb # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      hide!

      class_option :password_based, type: :boolean, default: false

      def create_files
        template "app/views/sessions/new.html.erb"

        if options.password_based?
          template "app/views/passwords/new.html.erb"
          template "app/views/passwords/edit.html.erb"
        else
          template "app/views/sessions/magic_links/show.html.erb"
        end

        template "app/views/my/passkeys/index.html.erb"
        template "app/views/my/passkeys/edit.html.erb"
        template "app/views/my/passkeys/_passkey.html.erb"
      end
    end
  end
end
