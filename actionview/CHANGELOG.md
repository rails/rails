*   `select_tag`'s `include_blank` option for generation for blank option tag, now adds an empty space label,
     when the value as well as content for option tag are empty, so that we confirm with html specification.
     Ref: https://www.w3.org/TR/html5/forms.html#the-option-element.

    Generation of option before:

    ```html
    <option value=""></option>
    ```

    Generation of option after:

    ```html
    <option value="" label=" "></option>
    ```

    *Vipul A M*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionview/CHANGELOG.md) for previous changes.
