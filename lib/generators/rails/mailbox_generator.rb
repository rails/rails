# frozen_string_literal: true

module Rails
  module Generators
    class MailboxGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      check_class_collision suffix: "Mailbox"

      def create_mailbox_file
        template "mailbox.rb", File.join("app/mailboxes", class_path, "#{file_name}_mailbox.rb")

        in_root do
          if behavior == :invoke && !File.exist?(application_mailbox_file_name)
            template "application_mailbox.rb", application_mailbox_file_name
          end
        end
      end

      hook_for :test_framework

      private
        def file_name # :doc:
          @_file_name ||= super.sub(/_mailbox\z/i, "")
        end

        def application_mailbox_file_name
          "app/mailboxes/application_mailbox.rb"
        end
    end
  end
end
