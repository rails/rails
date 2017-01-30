module ActionMailer
  # Provides the option to parameterize mailers in order to share instance variable
  # setup, processing, and common headers.
  #
  # Consider this example that does not use parameterization:
  #
  #   class InvitationsMailer < ApplicationMailer
  #     def account_invitation(inviter, invitee)
  #       @account = inviter.account
  #       @inviter = inviter
  #       @invitee = invitee
  #
  #       subject = "#{@inviter.name} invited you to their Basecamp (#{@account.name})"
  #
  #       mail \
  #         subject:   subject,
  #         to:        invitee.email_address,
  #         from:      common_address(inviter),
  #         reply_to:  inviter.email_address_with_name
  #     end
  #
  #     def project_invitation(project, inviter, invitee)
  #       @account = inviter.account
  #       @project = project
  #       @inviter = inviter
  #       @invitee = invitee
  #       @summarizer = ProjectInvitationSummarizer.new(@project.bucket)
  #
  #       subject = "#{@inviter.name.familiar} added you to a project in Basecamp (#{@account.name})"
  #
  #       mail \
  #         subject:   subject,
  #         to:        invitee.email_address,
  #         from:      common_address(inviter),
  #         reply_to:  inviter.email_address_with_name
  #     end
  #
  #     def bulk_project_invitation(projects, inviter, invitee)
  #       @account  = inviter.account
  #       @projects = projects.sort_by(&:name)
  #       @inviter  = inviter
  #       @invitee  = invitee
  #
  #       subject = "#{@inviter.name.familiar} added you to some new stuff in Basecamp (#{@account.name})"
  #
  #       mail \
  #         subject:   subject,
  #         to:        invitee.email_address,
  #         from:      common_address(inviter),
  #         reply_to:  inviter.email_address_with_name
  #     end
  #   end
  #
  #   InvitationsMailer.account_invitation(person_a, person_b).deliver_later
  #
  # Using parameterized mailers, this can be rewritten as:
  #
  #   class InvitationsMailer < ApplicationMailer
  #     before_action { @inviter, @invitee = params[:inviter], params[:invitee] }
  #     before_action { @account = params[:inviter].account }
  #
  #     default to:       -> { @invitee.email_address },
  #             from:     -> { common_address(@inviter) },
  #             reply_to: -> { @inviter.email_address_with_name }
  #
  #     def account_invitation
  #       mail subject: "#{@inviter.name} invited you to their Basecamp (#{@account.name})"
  #     end
  #
  #     def project_invitation
  #       @project    = params[:project]
  #       @summarizer = ProjectInvitationSummarizer.new(@project.bucket)
  #
  #        mail subject: "#{@inviter.name.familiar} added you to a project in Basecamp (#{@account.name})"
  #     end
  #
  #     def bulk_project_invitation
  #       @projects = params[:projects].sort_by(&:name)
  #
  #       mail subject: "#{@inviter.name.familiar} added you to some new stuff in Basecamp (#{@account.name})"
  #     end
  #   end
  #
  #   InvitationsMailer.with(inviter: person_a, invitee: person_b).account_invitation.deliver_later
  #
  # That's a big improvement! It's also fully backwards compatible. So you can start to gradually transition
  # mailers that stand to benefit the most from parameterization one by one and leave the others behind.
  module Parameterized
    extend ActiveSupport::Concern

    included do
      attr_accessor :params
    end

    class_methods do
      def with(params)
        ActionMailer::Parameterized::Mailer.new(self, params)
      end
    end

    class Mailer # :nodoc:
      def initialize(mailer, params)
        @mailer, @params = mailer, params
      end

      def method_missing(method_name, *args)
        if @mailer.action_methods.include?(method_name.to_s)
          ActionMailer::Parameterized::MessageDelivery.new(@mailer, method_name, @params, *args)
        else
          super
        end
      end
    end

    class MessageDelivery < ActionMailer::MessageDelivery # :nodoc:
      def initialize(mailer_class, action, params, *args)
        super(mailer_class, action, *args)
        @params = params
      end

      private
        def processed_mailer
          @processed_mailer ||= @mailer_class.new.tap do |mailer|
            mailer.params = @params
            mailer.process @action, *@args
          end
        end

        def enqueue_delivery(delivery_method, options = {})
          if processed?
            super
          else
            args = @mailer_class.name, @action.to_s, delivery_method.to_s, @params, *@args
            ActionMailer::Parameterized::DeliveryJob.set(options).perform_later(*args)
          end
        end
    end

    class DeliveryJob < ActionMailer::DeliveryJob # :nodoc:
      def perform(mailer, mail_method, delivery_method, params, *args)
        mailer.constantize.with(params).public_send(mail_method, *args).send(delivery_method)
      end
    end
  end
end
