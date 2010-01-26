jQuery(function ($) {
    function evalAttribute(element, attribute) {
        var el = $(element); 
        var attr = el.attr('data-' + attribute);
        if(attr) {
            eval(attr);
        }
    }

    $('form[data-remote="true"],a[data-remote="true"],input[data-remote="true"]')
        .live('before', function (e) {
            evalAttribute(this, 'onbefore'); 
        })
        .live('after', function (e, xhr) {
            evalAttribute(this, 'onafter'); 
        })
        .live('loading', function (e, xhr) {
            evalAttribute(this, 'onloading'); 
        })
        .live('loaded', function (e, xhr) {
            evalAttribute(this, 'onloaded'); 
        })
        .live('complete', function (e, xhr) {
            evalAttribute(this, 'oncomplete'); 
            evalAttribute(this, 'on' + xhr.status); 
        })
        .live('success', function (e, data, status, xhr) {
            evalAttribute(this, 'onsuccess'); 
        })
        .live('failure', function (e, xhr, status, error) {
            evalAttribute(this, 'onfailure'); 
        });
});
