# frozen_string_literal: true

module TestUnit
  module Generators
    class MailboxGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      check_class_collision suffix: 'MailboxTest'

      def create_test_files
        template 'mailbox_test.rb', File.join('test/mailboxes', class_path, "#{file_name}_mailbox_test.rb")
      end

      private
        def file_name # :doc:
          @_file_name ||= super.sub(/_mailbox\z/i, '')
        end
    end
  end
end
