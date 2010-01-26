jQuery(function ($) {

    function handleRemote (e) {
        var el          = $(this),
            data        = [],
            condition   = el.attr('data-condition') ? eval(el.attr('data-condition')) : true,
            method      = el.attr('method') || el.attr('data-method') || 'POST',
            url         = el.attr('action') || el.attr('data-url') || '#',
            async       = el.attr('data-remote-type') === 'synchronous' ? false : true,
            update      = el.attr('data-update-success'),
            position    = el.attr('data-update-position');

        console.log(e);

        if (el.attr('data-submit')) {
            data = $('#' + el.attr('data-submit')).serializeArray();
        } else if (el.attr('data-with')) {
            data = el.attr('data-with');
        } else if(e.target.tagName.toUpperCase() == 'FORM') {
            data = el.serializeArray();
        }

        if(condition) {
            el.trigger('before');

            $.ajax({
                async: async,
                url: url,
                data: data,
                type: method.toUpperCase(),
                beforeSend: function (xhr) {
                    el.trigger('after', xhr);
                    el.trigger('loading', xhr);
                },
                success: function (data, status, xhr) {
                    el.trigger('success', [data, status, xhr]);
                    
                    if (update) {
                        var element = update.charAt(0) == '#' ? update : '#' + update;
                        if(position) {
                            switch(el.attr('data-update-position')) {
                                case "before":
                                    $(element).before(data); 
                                    break;
                                case "after":
                                    $(element).after(data); 
                                    break;
                                case "top":
                                    $(element).prepend(data); 
                                    break;
                                case "bottom":
                                    $(element).append(data); 
                                    break;
                                default:
                                    $(element).append(data); 
                                    break;
                            }
                        } else {
                            $(element).html(data); 
                        }
                    }
                },
                complete: function (xhr) {
                    el.trigger('complete', xhr);
                    el.trigger('loaded', xhr);
                },
                error: function (xhr, status, error) {
                    el.trigger('failure', [xhr, status, error]);
                }
            });
        }

        e.preventDefault();
    }

    $('form[data-remote="true"]').live('submit', handleRemote);
    $('a[data-remote="true"],input[data-remote="true"]').live('click', handleRemote);
});
