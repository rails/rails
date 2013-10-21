* Instrument the generation of Action Mailer messages. The time it takes to
  generate a message is written to the log.

  *Daniel Schierbeck*

* invoke mailer defaults as procs only if they are procs, do not convert
  with to_proc.  That an object is convertible to a proc does not mean it's
  meant to be always used as a proc.  Fixes #11533

  *Alex Tsukernik*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionmailer/CHANGELOG.md) for previous changes.
