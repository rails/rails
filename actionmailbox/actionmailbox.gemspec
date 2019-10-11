# -*- encoding: utf-8 -*-
# stub: actionmailbox 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "actionmailbox".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/actionmailbox/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/actionmailbox" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze, "George Claghorn".freeze]
  s.date = "2019-10-05"
  s.description = "Receive and process incoming emails in Rails applications.".freeze
  s.email = ["david@loudthinking.com".freeze, "george@basecamp.com".freeze]
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "app/controllers/action_mailbox".freeze, "app/controllers/action_mailbox/base_controller.rb".freeze, "app/controllers/action_mailbox/ingresses".freeze, "app/controllers/action_mailbox/ingresses/mailgun".freeze, "app/controllers/action_mailbox/ingresses/mailgun/inbound_emails_controller.rb".freeze, "app/controllers/action_mailbox/ingresses/mandrill".freeze, "app/controllers/action_mailbox/ingresses/mandrill/inbound_emails_controller.rb".freeze, "app/controllers/action_mailbox/ingresses/postmark".freeze, "app/controllers/action_mailbox/ingresses/postmark/inbound_emails_controller.rb".freeze, "app/controllers/action_mailbox/ingresses/relay".freeze, "app/controllers/action_mailbox/ingresses/relay/inbound_emails_controller.rb".freeze, "app/controllers/action_mailbox/ingresses/sendgrid".freeze, "app/controllers/action_mailbox/ingresses/sendgrid/inbound_emails_controller.rb".freeze, "app/controllers/rails".freeze, "app/controllers/rails/conductor".freeze, "app/controllers/rails/conductor/action_mailbox".freeze, "app/controllers/rails/conductor/action_mailbox/inbound_emails_controller.rb".freeze, "app/controllers/rails/conductor/action_mailbox/reroutes_controller.rb".freeze, "app/controllers/rails/conductor/base_controller.rb".freeze, "app/jobs/action_mailbox".freeze, "app/jobs/action_mailbox/incineration_job.rb".freeze, "app/jobs/action_mailbox/routing_job.rb".freeze, "app/models/action_mailbox".freeze, "app/models/action_mailbox/inbound_email".freeze, "app/models/action_mailbox/inbound_email.rb".freeze, "app/models/action_mailbox/inbound_email/incineratable".freeze, "app/models/action_mailbox/inbound_email/incineratable.rb".freeze, "app/models/action_mailbox/inbound_email/incineratable/incineration.rb".freeze, "app/models/action_mailbox/inbound_email/message_id.rb".freeze, "app/models/action_mailbox/inbound_email/routable.rb".freeze, "app/views/layouts/rails".freeze, "app/views/layouts/rails/conductor.html.erb".freeze, "app/views/rails".freeze, "app/views/rails/conductor".freeze, "app/views/rails/conductor/action_mailbox".freeze, "app/views/rails/conductor/action_mailbox/inbound_emails".freeze, "app/views/rails/conductor/action_mailbox/inbound_emails/index.html.erb".freeze, "app/views/rails/conductor/action_mailbox/inbound_emails/new.html.erb".freeze, "app/views/rails/conductor/action_mailbox/inbound_emails/show.html.erb".freeze, "config/routes.rb".freeze, "db/migrate/20180917164000_create_action_mailbox_tables.rb".freeze, "lib/action_mailbox".freeze, "lib/action_mailbox.rb".freeze, "lib/action_mailbox/base.rb".freeze, "lib/action_mailbox/callbacks.rb".freeze, "lib/action_mailbox/engine.rb".freeze, "lib/action_mailbox/gem_version.rb".freeze, "lib/action_mailbox/mail_ext".freeze, "lib/action_mailbox/mail_ext.rb".freeze, "lib/action_mailbox/mail_ext/address_equality.rb".freeze, "lib/action_mailbox/mail_ext/address_wrapping.rb".freeze, "lib/action_mailbox/mail_ext/addresses.rb".freeze, "lib/action_mailbox/mail_ext/from_source.rb".freeze, "lib/action_mailbox/mail_ext/recipients.rb".freeze, "lib/action_mailbox/relayer.rb".freeze, "lib/action_mailbox/router".freeze, "lib/action_mailbox/router.rb".freeze, "lib/action_mailbox/router/route.rb".freeze, "lib/action_mailbox/routing.rb".freeze, "lib/action_mailbox/test_case.rb".freeze, "lib/action_mailbox/test_helper.rb".freeze, "lib/action_mailbox/version.rb".freeze, "lib/rails".freeze, "lib/rails/generators".freeze, "lib/rails/generators/installer.rb".freeze, "lib/rails/generators/mailbox".freeze, "lib/rails/generators/mailbox/USAGE".freeze, "lib/rails/generators/mailbox/mailbox_generator.rb".freeze, "lib/rails/generators/mailbox/templates".freeze, "lib/rails/generators/mailbox/templates/application_mailbox.rb.tt".freeze, "lib/rails/generators/mailbox/templates/mailbox.rb.tt".freeze, "lib/rails/generators/test_unit".freeze, "lib/rails/generators/test_unit/mailbox_generator.rb".freeze, "lib/rails/generators/test_unit/templates".freeze, "lib/rails/generators/test_unit/templates/mailbox_test.rb.tt".freeze, "lib/tasks/ingress.rake".freeze, "lib/tasks/install.rake".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Inbound email handling framework.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<mail>.freeze, [">= 2.7.1"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<mail>.freeze, [">= 2.7.1"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<mail>.freeze, [">= 2.7.1"])
  end
end
