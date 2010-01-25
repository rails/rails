jQuery(function ($) {
    $('form[data-remote="true"]').live('submit', function (e) {
        var form        = $(this),
            data        = [],
            condition   = form.attr('data-condition') ? eval(form.attr('data-condition')) : true;


        if (form.attr('data-submit')) {
            data = $('#' + form.attr('data-submit')).serializeArray();
        } else if (form.attr('data-with')) {
            data = form.attr('data-with');
        } else {
            data = form.serializeArray();
        }

        if(condition) {
            form.trigger('before');

            $.ajax({
                async: form.attr('data-remote-type') === 'synchronous' ? false : true,
                url: form.attr('action'),
                method: form.attr('method'),
                data: data,
                beforeSend: function (xhr) {
                    form.trigger('after', xhr);
                    form.trigger('loading', xhr);
                },
                success: function (data, status, xhr) {
                    var update = form.attr('data-update-success');
                    form.trigger('success', [data, status, xhr]);
                    
                    if (update) {
                        $(update + ', #' + update).html(data); 
                    }
                },
                complete: function (xhr) {
                    form.trigger('complete', xhr);
                    form.trigger('loaded', xhr);
                },
                error: function (xhr, status, error) {
                    form.trigger('failure', [xhr, status, error]);
                }
            });
        }

        e.preventDefault();
    });
});
