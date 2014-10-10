*   Fix nested `has many :through` associations on unpersisted parent instances.

    For example, if you have

        class Post < ActiveRecord::Base
          has_many :books, through: :author
          has_many :subscriptions, through: :books
        end

        class Author < ActiveRecord::Base
          has_one :post
          has_many :books
          has_many :subscriptions, through: :books
        end

        class Book < ActiveRecord::Base
          belongs_to :author
          has_many :subscriptions
        end

        class Subscription < ActiveRecord::Base
          belongs_to :book
        end

    Before:
        If `post` is not persisted, e.g `post = Post.new`, then `post.subscriptions`
        will be empty no matter what.

    After:
        If `post` is not persisted, then `post.subscriptions` can be set and used
        just like it would if `post` were persisted.

    Fixes #16313.

    *Zoltan Kiss*

*   Add `assert_enqueued_emails` and `assert_no_enqueued_emails`.

    Example:

        def test_emails
          assert_enqueued_emails 2 do
            ContactMailer.welcome.deliver_later
            ContactMailer.welcome.deliver_later
          end
        end

        def test_no_emails
          assert_no_enqueued_emails do
            # No emails enqueued here
          end
        end

    *George Claghorn*

*   Add `_mailer` suffix to mailers created via generator, following the same
    naming convention used in controllers and jobs.

    *Carlos Souza*

*   Remove deprecate `*_path` helpers in email views.

    *Rafael Mendonça França*

*   Remove deprecated `deliver` and `deliver!` methods.

    *claudiob*

*   Template lookup now respects default locale and I18n fallbacks.

    Given the following templates:

        mailer/demo.html.erb
        mailer/demo.en.html.erb
        mailer/demo.pt.html.erb

    Before this change, for a locale that doesn't have its associated file, the
    `mailer/demo.html.erb` would be rendered even if `en` was the default locale.

    Now `mailer/demo.en.html.erb` has precedence over the file without locale.

    Also, it is possible to give a fallback.

        mailer/demo.pt.html.erb
        mailer/demo.pt-BR.html.erb

    So if the locale is `pt-PT`, `mailer/demo.pt.html.erb` will be rendered given
    the right I18n fallback configuration.

    *Rafael Mendonça França*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionmailer/CHANGELOG.md) for previous changes.
