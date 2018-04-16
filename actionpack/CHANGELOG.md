*   Fix strong parameters `permit!` with nested arrays

    Strong parameters doesn't support nested arrays, take as example: `[[{ name: 'Leonardo', age: 26 }]]`.
    This is separate from making `permit(something: [[:key]])` work properly, which is being addressed in #23650

    *Steve Hull*

*   Move default headers configuration into their own module that can be included in controllers.

    *Kevin Deisz*

*   Add method `dig` to `session`.

    *claudiob*, *Takumi Shotoku*

*   Controller level `force_ssl` has been deprecated in favor of
    `config.force_ssl`.

    *Derek Prior*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionpack/CHANGELOG.md) for previous changes.
