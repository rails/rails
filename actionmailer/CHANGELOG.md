* Fix ActionMailer testcase break with mail 2.5.4.
  ActionMailer's testcase was wrong, because :transfer_encoding option was ignored in mail 2.5.3.

  *kennyj*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionmailer/CHANGELOG.md) for previous changes.
