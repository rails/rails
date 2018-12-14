# frozen_string_literal: true

module Rails
  module Generators
    class MailboxGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [:process], banner: "method method"

      def check_class_collision
        class_collisions "#{class_name}Mailbox", "#{class_name}MailboxTest"
      end

      def create_mailbox_file
        template "mailbox.rb", File.join("app/mailboxes", class_path, "#{file_name}_mailbox.rb")

        in_root do
          if behavior == :invoke && !File.exist?(application_mailbox_file_name)
            template "application_mailbox.rb", application_mailbox_file_name
          end
        end

        template "mailbox_test.rb", File.join('test/mailboxes', class_path, "#{file_name}_mailbox_test.rb")
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
