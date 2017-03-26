Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/railties/CHANGELOG.md) for previous changes.


*   Specify form field ids when generating a scaffold.

    This makes sure that the labels are linked up with the fields. The
    regression was introduced when the template was switched to
    `form_with`.

    *Yves Senn*
