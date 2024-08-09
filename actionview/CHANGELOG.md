*   Add `datalist_tag` to create `datalist` form elements.

    Example:

        datalist_tag('countries_datalist', ['Argentina', ['Brazil', { class: 'brazilian_option' }],
                     ['Chile', 'CL', { disabled: true }]], { class: 'sa-countries-sample' })
        => <datalist id="countries_datalist" class="sa-countries-sample">
             <option value="Argentina">Argentina</option>
             <option value="Brazil" class="brazilian_option">Brazil</option>
             <option value="CL" disabled="disabled">Chile</option>
           </datalist>

    *Willian Gustavo Veiga*

*   Rename `text_area` methods into `textarea`

    Old names are still available as aliases.

    *Sean Doyle*

*   Rename `check_box*` methods into `checkbox*`.

    Old names are still available as aliases.

    *Jean Boussier*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
