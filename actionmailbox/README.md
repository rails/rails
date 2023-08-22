# Action Mailbox

Action Mailbox routes incoming emails to controller-like mailboxes for processing in \Rails. It ships with ingresses for Mailgun, Mandrill, Postmark, and SendGrid. You can also handle inbound mails directly via the built-in Exim, Postfix, and Qmail ingresses.

The inbound emails are turned into `InboundEmail` records using Active Record and feature lifecycle tracking, storage of the original email on cloud storage via Active Storage, and responsible data handling with on-by-default incineration.

These inbound emails are routed asynchronously using Active Job to one or several dedicated mailboxes, which are capable of interacting directly with the rest of your domain model.

You can read more about Action Mailbox in the [Action Mailbox Basics](https://guides.rubyonrails.org/action_mailbox_basics.html) guide.

## License

Action Mailbox is released under the [MIT License](https://opensource.org/licenses/MIT).
