*   Support passing a `proc` to `:allow_nil` and `:allow_blank` for validators.

    Example use case:

        - Allow email to be empty if phone number given
        - If email is not blank: make sure it is an email, make sure it has a length between 1 and 40 chars

        validates :email, presence: true, length: 1..40, email: true, allow_blank: lambda{ |m| m.phone_number.present? }

    *Corin Langosch*

*   Removed deprecated `:tokenizer` in the length validator.

    *Rafael Mendonça França*

*   Removed deprecated methods in `ActiveModel::Errors`.

    `#get`, `#set`, `[]=`, `add_on_empty` and `add_on_blank`.

    *Rafael Mendonça França*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md) for previous changes.
