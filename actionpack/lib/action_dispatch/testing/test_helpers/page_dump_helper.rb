# frozen_string_literal: true

module ActionDispatch
  module TestHelpers
    module PageDumpHelper
      class InvalidResponse < StandardError; end

      # Saves the content of response body to a file and tries to open it in your browser.
      # Launchy must be present in your Gemfile for the page to open automatically.
      def save_and_open_page(path = html_dump_default_path)
        save_page(path).tap { |s_path| open_file(s_path) }
      end

      private
        def save_page(path = html_dump_default_path)
          raise InvalidResponse.new("Response is a redirection!") if response.redirection?
          path = Pathname.new(path)
          path.dirname.mkpath
          File.write(path, response.body)
          path
        end

        def open_file(path)
          require "launchy"
          Launchy.open(path)
        rescue LoadError
          warn "File saved to #{path}.\nPlease install the launchy gem to open the file automatically."
        end

        def html_dump_default_path
          Rails.root.join("tmp/html_dump", "#{method_name}_#{DateTime.current.to_i}.html").to_s
        end
    end
  end
end
