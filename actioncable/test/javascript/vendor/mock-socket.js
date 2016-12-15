(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
/*!
 * URI.js - Mutating URLs
 * IPv6 Support
 *
 * Version: 1.17.0
 *
 * Author: Rodney Rehm
 * Web: http://medialize.github.io/URI.js/
 *
 * Licensed under
 *   MIT License http://www.opensource.org/licenses/mit-license
 *   GPL v3 http://opensource.org/licenses/GPL-3.0
 *
 */

(function (root, factory) {
  'use strict';
  // https://github.com/umdjs/umd/blob/master/returnExports.js
  if (typeof exports === 'object') {
    // Node
    module.exports = factory();
  } else if (typeof define === 'function' && define.amd) {
    // AMD. Register as an anonymous module.
    define(factory);
  } else {
    // Browser globals (root is window)
    root.IPv6 = factory(root);
  }
}(this, function (root) {
  'use strict';

  /*
  var _in = "fe80:0000:0000:0000:0204:61ff:fe9d:f156";
  var _out = IPv6.best(_in);
  var _expected = "fe80::204:61ff:fe9d:f156";

  console.log(_in, _out, _expected, _out === _expected);
  */

  // save current IPv6 variable, if any
  var _IPv6 = root && root.IPv6;

  function bestPresentation(address) {
    // based on:
    // Javascript to test an IPv6 address for proper format, and to
    // present the "best text representation" according to IETF Draft RFC at
    // http://tools.ietf.org/html/draft-ietf-6man-text-addr-representation-04
    // 8 Feb 2010 Rich Brown, Dartware, LLC
    // Please feel free to use this code as long as you provide a link to
    // http://www.intermapper.com
    // http://intermapper.com/support/tools/IPV6-Validator.aspx
    // http://download.dartware.com/thirdparty/ipv6validator.js

    var _address = address.toLowerCase();
    var segments = _address.split(':');
    var length = segments.length;
    var total = 8;

    // trim colons (:: or ::a:b:c… or …a:b:c::)
    if (segments[0] === '' && segments[1] === '' && segments[2] === '') {
      // must have been ::
      // remove first two items
      segments.shift();
      segments.shift();
    } else if (segments[0] === '' && segments[1] === '') {
      // must have been ::xxxx
      // remove the first item
      segments.shift();
    } else if (segments[length - 1] === '' && segments[length - 2] === '') {
      // must have been xxxx::
      segments.pop();
    }

    length = segments.length;

    // adjust total segments for IPv4 trailer
    if (segments[length - 1].indexOf('.') !== -1) {
      // found a "." which means IPv4
      total = 7;
    }

    // fill empty segments them with "0000"
    var pos;
    for (pos = 0; pos < length; pos++) {
      if (segments[pos] === '') {
        break;
      }
    }

    if (pos < total) {
      segments.splice(pos, 1, '0000');
      while (segments.length < total) {
        segments.splice(pos, 0, '0000');
      }

      length = segments.length;
    }

    // strip leading zeros
    var _segments;
    for (var i = 0; i < total; i++) {
      _segments = segments[i].split('');
      for (var j = 0; j < 3 ; j++) {
        if (_segments[0] === '0' && _segments.length > 1) {
          _segments.splice(0,1);
        } else {
          break;
        }
      }

      segments[i] = _segments.join('');
    }

    // find longest sequence of zeroes and coalesce them into one segment
    var best = -1;
    var _best = 0;
    var _current = 0;
    var current = -1;
    var inzeroes = false;
    // i; already declared

    for (i = 0; i < total; i++) {
      if (inzeroes) {
        if (segments[i] === '0') {
          _current += 1;
        } else {
          inzeroes = false;
          if (_current > _best) {
            best = current;
            _best = _current;
          }
        }
      } else {
        if (segments[i] === '0') {
          inzeroes = true;
          current = i;
          _current = 1;
        }
      }
    }

    if (_current > _best) {
      best = current;
      _best = _current;
    }

    if (_best > 1) {
      segments.splice(best, _best, '');
    }

    length = segments.length;

    // assemble remaining segments
    var result = '';
    if (segments[0] === '')  {
      result = ':';
    }

    for (i = 0; i < length; i++) {
      result += segments[i];
      if (i === length - 1) {
        break;
      }

      result += ':';
    }

    if (segments[length - 1] === '') {
      result += ':';
    }

    return result;
  }

  function noConflict() {
    /*jshint validthis: true */
    if (root.IPv6 === this) {
      root.IPv6 = _IPv6;
    }
  
    return this;
  }

  return {
    best: bestPresentation,
    noConflict: noConflict
  };
}));

},{}],2:[function(require,module,exports){
/*!
 * URI.js - Mutating URLs
 * Second Level Domain (SLD) Support
 *
 * Version: 1.17.0
 *
 * Author: Rodney Rehm
 * Web: http://medialize.github.io/URI.js/
 *
 * Licensed under
 *   MIT License http://www.opensource.org/licenses/mit-license
 *   GPL v3 http://opensource.org/licenses/GPL-3.0
 *
 */

(function (root, factory) {
  'use strict';
  // https://github.com/umdjs/umd/blob/master/returnExports.js
  if (typeof exports === 'object') {
    // Node
    module.exports = factory();
  } else if (typeof define === 'function' && define.amd) {
    // AMD. Register as an anonymous module.
    define(factory);
  } else {
    // Browser globals (root is window)
    root.SecondLevelDomains = factory(root);
  }
}(this, function (root) {
  'use strict';

  // save current SecondLevelDomains variable, if any
  var _SecondLevelDomains = root && root.SecondLevelDomains;

  var SLD = {
    // list of known Second Level Domains
    // converted list of SLDs from https://github.com/gavingmiller/second-level-domains
    // ----
    // publicsuffix.org is more current and actually used by a couple of browsers internally.
    // downside is it also contains domains like "dyndns.org" - which is fine for the security
    // issues browser have to deal with (SOP for cookies, etc) - but is way overboard for URI.js
    // ----
    list: {
      'ac':' com gov mil net org ',
      'ae':' ac co gov mil name net org pro sch ',
      'af':' com edu gov net org ',
      'al':' com edu gov mil net org ',
      'ao':' co ed gv it og pb ',
      'ar':' com edu gob gov int mil net org tur ',
      'at':' ac co gv or ',
      'au':' asn com csiro edu gov id net org ',
      'ba':' co com edu gov mil net org rs unbi unmo unsa untz unze ',
      'bb':' biz co com edu gov info net org store tv ',
      'bh':' biz cc com edu gov info net org ',
      'bn':' com edu gov net org ',
      'bo':' com edu gob gov int mil net org tv ',
      'br':' adm adv agr am arq art ato b bio blog bmd cim cng cnt com coop ecn edu eng esp etc eti far flog fm fnd fot fst g12 ggf gov imb ind inf jor jus lel mat med mil mus net nom not ntr odo org ppg pro psc psi qsl rec slg srv tmp trd tur tv vet vlog wiki zlg ',
      'bs':' com edu gov net org ',
      'bz':' du et om ov rg ',
      'ca':' ab bc mb nb nf nl ns nt nu on pe qc sk yk ',
      'ck':' biz co edu gen gov info net org ',
      'cn':' ac ah bj com cq edu fj gd gov gs gx gz ha hb he hi hl hn jl js jx ln mil net nm nx org qh sc sd sh sn sx tj tw xj xz yn zj ',
      'co':' com edu gov mil net nom org ',
      'cr':' ac c co ed fi go or sa ',
      'cy':' ac biz com ekloges gov ltd name net org parliament press pro tm ',
      'do':' art com edu gob gov mil net org sld web ',
      'dz':' art asso com edu gov net org pol ',
      'ec':' com edu fin gov info med mil net org pro ',
      'eg':' com edu eun gov mil name net org sci ',
      'er':' com edu gov ind mil net org rochest w ',
      'es':' com edu gob nom org ',
      'et':' biz com edu gov info name net org ',
      'fj':' ac biz com info mil name net org pro ',
      'fk':' ac co gov net nom org ',
      'fr':' asso com f gouv nom prd presse tm ',
      'gg':' co net org ',
      'gh':' com edu gov mil org ',
      'gn':' ac com gov net org ',
      'gr':' com edu gov mil net org ',
      'gt':' com edu gob ind mil net org ',
      'gu':' com edu gov net org ',
      'hk':' com edu gov idv net org ',
      'hu':' 2000 agrar bolt casino city co erotica erotika film forum games hotel info ingatlan jogasz konyvelo lakas media news org priv reklam sex shop sport suli szex tm tozsde utazas video ',
      'id':' ac co go mil net or sch web ',
      'il':' ac co gov idf k12 muni net org ',
      'in':' ac co edu ernet firm gen gov i ind mil net nic org res ',
      'iq':' com edu gov i mil net org ',
      'ir':' ac co dnssec gov i id net org sch ',
      'it':' edu gov ',
      'je':' co net org ',
      'jo':' com edu gov mil name net org sch ',
      'jp':' ac ad co ed go gr lg ne or ',
      'ke':' ac co go info me mobi ne or sc ',
      'kh':' com edu gov mil net org per ',
      'ki':' biz com de edu gov info mob net org tel ',
      'km':' asso com coop edu gouv k medecin mil nom notaires pharmaciens presse tm veterinaire ',
      'kn':' edu gov net org ',
      'kr':' ac busan chungbuk chungnam co daegu daejeon es gangwon go gwangju gyeongbuk gyeonggi gyeongnam hs incheon jeju jeonbuk jeonnam k kg mil ms ne or pe re sc seoul ulsan ',
      'kw':' com edu gov net org ',
      'ky':' com edu gov net org ',
      'kz':' com edu gov mil net org ',
      'lb':' com edu gov net org ',
      'lk':' assn com edu gov grp hotel int ltd net ngo org sch soc web ',
      'lr':' com edu gov net org ',
      'lv':' asn com conf edu gov id mil net org ',
      'ly':' com edu gov id med net org plc sch ',
      'ma':' ac co gov m net org press ',
      'mc':' asso tm ',
      'me':' ac co edu gov its net org priv ',
      'mg':' com edu gov mil nom org prd tm ',
      'mk':' com edu gov inf name net org pro ',
      'ml':' com edu gov net org presse ',
      'mn':' edu gov org ',
      'mo':' com edu gov net org ',
      'mt':' com edu gov net org ',
      'mv':' aero biz com coop edu gov info int mil museum name net org pro ',
      'mw':' ac co com coop edu gov int museum net org ',
      'mx':' com edu gob net org ',
      'my':' com edu gov mil name net org sch ',
      'nf':' arts com firm info net other per rec store web ',
      'ng':' biz com edu gov mil mobi name net org sch ',
      'ni':' ac co com edu gob mil net nom org ',
      'np':' com edu gov mil net org ',
      'nr':' biz com edu gov info net org ',
      'om':' ac biz co com edu gov med mil museum net org pro sch ',
      'pe':' com edu gob mil net nom org sld ',
      'ph':' com edu gov i mil net ngo org ',
      'pk':' biz com edu fam gob gok gon gop gos gov net org web ',
      'pl':' art bialystok biz com edu gda gdansk gorzow gov info katowice krakow lodz lublin mil net ngo olsztyn org poznan pwr radom slupsk szczecin torun warszawa waw wroc wroclaw zgora ',
      'pr':' ac biz com edu est gov info isla name net org pro prof ',
      'ps':' com edu gov net org plo sec ',
      'pw':' belau co ed go ne or ',
      'ro':' arts com firm info nom nt org rec store tm www ',
      'rs':' ac co edu gov in org ',
      'sb':' com edu gov net org ',
      'sc':' com edu gov net org ',
      'sh':' co com edu gov net nom org ',
      'sl':' com edu gov net org ',
      'st':' co com consulado edu embaixada gov mil net org principe saotome store ',
      'sv':' com edu gob org red ',
      'sz':' ac co org ',
      'tr':' av bbs bel biz com dr edu gen gov info k12 name net org pol tel tsk tv web ',
      'tt':' aero biz cat co com coop edu gov info int jobs mil mobi museum name net org pro tel travel ',
      'tw':' club com ebiz edu game gov idv mil net org ',
      'mu':' ac co com gov net or org ',
      'mz':' ac co edu gov org ',
      'na':' co com ',
      'nz':' ac co cri geek gen govt health iwi maori mil net org parliament school ',
      'pa':' abo ac com edu gob ing med net nom org sld ',
      'pt':' com edu gov int net nome org publ ',
      'py':' com edu gov mil net org ',
      'qa':' com edu gov mil net org ',
      're':' asso com nom ',
      'ru':' ac adygeya altai amur arkhangelsk astrakhan bashkiria belgorod bir bryansk buryatia cbg chel chelyabinsk chita chukotka chuvashia com dagestan e-burg edu gov grozny int irkutsk ivanovo izhevsk jar joshkar-ola kalmykia kaluga kamchatka karelia kazan kchr kemerovo khabarovsk khakassia khv kirov koenig komi kostroma kranoyarsk kuban kurgan kursk lipetsk magadan mari mari-el marine mil mordovia mosreg msk murmansk nalchik net nnov nov novosibirsk nsk omsk orenburg org oryol penza perm pp pskov ptz rnd ryazan sakhalin samara saratov simbirsk smolensk spb stavropol stv surgut tambov tatarstan tom tomsk tsaritsyn tsk tula tuva tver tyumen udm udmurtia ulan-ude vladikavkaz vladimir vladivostok volgograd vologda voronezh vrn vyatka yakutia yamal yekaterinburg yuzhno-sakhalinsk ',
      'rw':' ac co com edu gouv gov int mil net ',
      'sa':' com edu gov med net org pub sch ',
      'sd':' com edu gov info med net org tv ',
      'se':' a ac b bd c d e f g h i k l m n o org p parti pp press r s t tm u w x y z ',
      'sg':' com edu gov idn net org per ',
      'sn':' art com edu gouv org perso univ ',
      'sy':' com edu gov mil net news org ',
      'th':' ac co go in mi net or ',
      'tj':' ac biz co com edu go gov info int mil name net nic org test web ',
      'tn':' agrinet com defense edunet ens fin gov ind info intl mincom nat net org perso rnrt rns rnu tourism ',
      'tz':' ac co go ne or ',
      'ua':' biz cherkassy chernigov chernovtsy ck cn co com crimea cv dn dnepropetrovsk donetsk dp edu gov if in ivano-frankivsk kh kharkov kherson khmelnitskiy kiev kirovograd km kr ks kv lg lugansk lutsk lviv me mk net nikolaev od odessa org pl poltava pp rovno rv sebastopol sumy te ternopil uzhgorod vinnica vn zaporizhzhe zhitomir zp zt ',
      'ug':' ac co go ne or org sc ',
      'uk':' ac bl british-library co cym gov govt icnet jet lea ltd me mil mod national-library-scotland nel net nhs nic nls org orgn parliament plc police sch scot soc ',
      'us':' dni fed isa kids nsn ',
      'uy':' com edu gub mil net org ',
      've':' co com edu gob info mil net org web ',
      'vi':' co com k12 net org ',
      'vn':' ac biz com edu gov health info int name net org pro ',
      'ye':' co com gov ltd me net org plc ',
      'yu':' ac co edu gov org ',
      'za':' ac agric alt bourse city co cybernet db edu gov grondar iaccess imt inca landesign law mil net ngo nis nom olivetti org pix school tm web ',
      'zm':' ac co com edu gov net org sch '
    },
    // gorhill 2013-10-25: Using indexOf() instead Regexp(). Significant boost
    // in both performance and memory footprint. No initialization required.
    // http://jsperf.com/uri-js-sld-regex-vs-binary-search/4
    // Following methods use lastIndexOf() rather than array.split() in order
    // to avoid any memory allocations.
    has: function(domain) {
      var tldOffset = domain.lastIndexOf('.');
      if (tldOffset <= 0 || tldOffset >= (domain.length-1)) {
        return false;
      }
      var sldOffset = domain.lastIndexOf('.', tldOffset-1);
      if (sldOffset <= 0 || sldOffset >= (tldOffset-1)) {
        return false;
      }
      var sldList = SLD.list[domain.slice(tldOffset+1)];
      if (!sldList) {
        return false;
      }
      return sldList.indexOf(' ' + domain.slice(sldOffset+1, tldOffset) + ' ') >= 0;
    },
    is: function(domain) {
      var tldOffset = domain.lastIndexOf('.');
      if (tldOffset <= 0 || tldOffset >= (domain.length-1)) {
        return false;
      }
      var sldOffset = domain.lastIndexOf('.', tldOffset-1);
      if (sldOffset >= 0) {
        return false;
      }
      var sldList = SLD.list[domain.slice(tldOffset+1)];
      if (!sldList) {
        return false;
      }
      return sldList.indexOf(' ' + domain.slice(0, tldOffset) + ' ') >= 0;
    },
    get: function(domain) {
      var tldOffset = domain.lastIndexOf('.');
      if (tldOffset <= 0 || tldOffset >= (domain.length-1)) {
        return null;
      }
      var sldOffset = domain.lastIndexOf('.', tldOffset-1);
      if (sldOffset <= 0 || sldOffset >= (tldOffset-1)) {
        return null;
      }
      var sldList = SLD.list[domain.slice(tldOffset+1)];
      if (!sldList) {
        return null;
      }
      if (sldList.indexOf(' ' + domain.slice(sldOffset+1, tldOffset) + ' ') < 0) {
        return null;
      }
      return domain.slice(sldOffset+1);
    },
    noConflict: function(){
      if (root.SecondLevelDomains === this) {
        root.SecondLevelDomains = _SecondLevelDomains;
      }
      return this;
    }
  };

  return SLD;
}));

},{}],3:[function(require,module,exports){
/*!
 * URI.js - Mutating URLs
 *
 * Version: 1.17.0
 *
 * Author: Rodney Rehm
 * Web: http://medialize.github.io/URI.js/
 *
 * Licensed under
 *   MIT License http://www.opensource.org/licenses/mit-license
 *   GPL v3 http://opensource.org/licenses/GPL-3.0
 *
 */
(function (root, factory) {
  'use strict';
  // https://github.com/umdjs/umd/blob/master/returnExports.js
  if (typeof exports === 'object') {
    // Node
    module.exports = factory(require('./punycode'), require('./IPv6'), require('./SecondLevelDomains'));
  } else if (typeof define === 'function' && define.amd) {
    // AMD. Register as an anonymous module.
    define(['./punycode', './IPv6', './SecondLevelDomains'], factory);
  } else {
    // Browser globals (root is window)
    root.URI = factory(root.punycode, root.IPv6, root.SecondLevelDomains, root);
  }
}(this, function (punycode, IPv6, SLD, root) {
  'use strict';
  /*global location, escape, unescape */
  // FIXME: v2.0.0 renamce non-camelCase properties to uppercase
  /*jshint camelcase: false */

  // save current URI variable, if any
  var _URI = root && root.URI;

  function URI(url, base) {
    var _urlSupplied = arguments.length >= 1;
    var _baseSupplied = arguments.length >= 2;

    // Allow instantiation without the 'new' keyword
    if (!(this instanceof URI)) {
      if (_urlSupplied) {
        if (_baseSupplied) {
          return new URI(url, base);
        }

        return new URI(url);
      }

      return new URI();
    }

    if (url === undefined) {
      if (_urlSupplied) {
        throw new TypeError('undefined is not a valid argument for URI');
      }

      if (typeof location !== 'undefined') {
        url = location.href + '';
      } else {
        url = '';
      }
    }

    this.href(url);

    // resolve to base according to http://dvcs.w3.org/hg/url/raw-file/tip/Overview.html#constructor
    if (base !== undefined) {
      return this.absoluteTo(base);
    }

    return this;
  }

  URI.version = '1.17.0';

  var p = URI.prototype;
  var hasOwn = Object.prototype.hasOwnProperty;

  function escapeRegEx(string) {
    // https://github.com/medialize/URI.js/commit/85ac21783c11f8ccab06106dba9735a31a86924d#commitcomment-821963
    return string.replace(/([.*+?^=!:${}()|[\]\/\\])/g, '\\$1');
  }

  function getType(value) {
    // IE8 doesn't return [Object Undefined] but [Object Object] for undefined value
    if (value === undefined) {
      return 'Undefined';
    }

    return String(Object.prototype.toString.call(value)).slice(8, -1);
  }

  function isArray(obj) {
    return getType(obj) === 'Array';
  }

  function filterArrayValues(data, value) {
    var lookup = {};
    var i, length;

    if (getType(value) === 'RegExp') {
      lookup = null;
    } else if (isArray(value)) {
      for (i = 0, length = value.length; i < length; i++) {
        lookup[value[i]] = true;
      }
    } else {
      lookup[value] = true;
    }

    for (i = 0, length = data.length; i < length; i++) {
      /*jshint laxbreak: true */
      var _match = lookup && lookup[data[i]] !== undefined
        || !lookup && value.test(data[i]);
      /*jshint laxbreak: false */
      if (_match) {
        data.splice(i, 1);
        length--;
        i--;
      }
    }

    return data;
  }

  function arrayContains(list, value) {
    var i, length;

    // value may be string, number, array, regexp
    if (isArray(value)) {
      // Note: this can be optimized to O(n) (instead of current O(m * n))
      for (i = 0, length = value.length; i < length; i++) {
        if (!arrayContains(list, value[i])) {
          return false;
        }
      }

      return true;
    }

    var _type = getType(value);
    for (i = 0, length = list.length; i < length; i++) {
      if (_type === 'RegExp') {
        if (typeof list[i] === 'string' && list[i].match(value)) {
          return true;
        }
      } else if (list[i] === value) {
        return true;
      }
    }

    return false;
  }

  function arraysEqual(one, two) {
    if (!isArray(one) || !isArray(two)) {
      return false;
    }

    // arrays can't be equal if they have different amount of content
    if (one.length !== two.length) {
      return false;
    }

    one.sort();
    two.sort();

    for (var i = 0, l = one.length; i < l; i++) {
      if (one[i] !== two[i]) {
        return false;
      }
    }

    return true;
  }

  function trimSlashes(text) {
    var trim_expression = /^\/+|\/+$/g;
    return text.replace(trim_expression, '');
  }

  URI._parts = function() {
    return {
      protocol: null,
      username: null,
      password: null,
      hostname: null,
      urn: null,
      port: null,
      path: null,
      query: null,
      fragment: null,
      // state
      duplicateQueryParameters: URI.duplicateQueryParameters,
      escapeQuerySpace: URI.escapeQuerySpace
    };
  };
  // state: allow duplicate query parameters (a=1&a=1)
  URI.duplicateQueryParameters = false;
  // state: replaces + with %20 (space in query strings)
  URI.escapeQuerySpace = true;
  // static properties
  URI.protocol_expression = /^[a-z][a-z0-9.+-]*$/i;
  URI.idn_expression = /[^a-z0-9\.-]/i;
  URI.punycode_expression = /(xn--)/i;
  // well, 333.444.555.666 matches, but it sure ain't no IPv4 - do we care?
  URI.ip4_expression = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
  // credits to Rich Brown
  // source: http://forums.intermapper.com/viewtopic.php?p=1096#1096
  // specification: http://www.ietf.org/rfc/rfc4291.txt
  URI.ip6_expression = /^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/;
  // expression used is "gruber revised" (@gruber v2) determined to be the
  // best solution in a regex-golf we did a couple of ages ago at
  // * http://mathiasbynens.be/demo/url-regex
  // * http://rodneyrehm.de/t/url-regex.html
  URI.find_uri_expression = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/ig;
  URI.findUri = {
    // valid "scheme://" or "www."
    start: /\b(?:([a-z][a-z0-9.+-]*:\/\/)|www\.)/gi,
    // everything up to the next whitespace
    end: /[\s\r\n]|$/,
    // trim trailing punctuation captured by end RegExp
    trim: /[`!()\[\]{};:'".,<>?«»“”„‘’]+$/
  };
  // http://www.iana.org/assignments/uri-schemes.html
  // http://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Well-known_ports
  URI.defaultPorts = {
    http: '80',
    https: '443',
    ftp: '21',
    gopher: '70',
    ws: '80',
    wss: '443'
  };
  // allowed hostname characters according to RFC 3986
  // ALPHA DIGIT "-" "." "_" "~" "!" "$" "&" "'" "(" ")" "*" "+" "," ";" "=" %encoded
  // I've never seen a (non-IDN) hostname other than: ALPHA DIGIT . -
  URI.invalid_hostname_characters = /[^a-zA-Z0-9\.-]/;
  // map DOM Elements to their URI attribute
  URI.domAttributes = {
    'a': 'href',
    'blockquote': 'cite',
    'link': 'href',
    'base': 'href',
    'script': 'src',
    'form': 'action',
    'img': 'src',
    'area': 'href',
    'iframe': 'src',
    'embed': 'src',
    'source': 'src',
    'track': 'src',
    'input': 'src', // but only if type="image"
    'audio': 'src',
    'video': 'src'
  };
  URI.getDomAttribute = function(node) {
    if (!node || !node.nodeName) {
      return undefined;
    }

    var nodeName = node.nodeName.toLowerCase();
    // <input> should only expose src for type="image"
    if (nodeName === 'input' && node.type !== 'image') {
      return undefined;
    }

    return URI.domAttributes[nodeName];
  };

  function escapeForDumbFirefox36(value) {
    // https://github.com/medialize/URI.js/issues/91
    return escape(value);
  }

  // encoding / decoding according to RFC3986
  function strictEncodeURIComponent(string) {
    // see https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/encodeURIComponent
    return encodeURIComponent(string)
      .replace(/[!'()*]/g, escapeForDumbFirefox36)
      .replace(/\*/g, '%2A');
  }
  URI.encode = strictEncodeURIComponent;
  URI.decode = decodeURIComponent;
  URI.iso8859 = function() {
    URI.encode = escape;
    URI.decode = unescape;
  };
  URI.unicode = function() {
    URI.encode = strictEncodeURIComponent;
    URI.decode = decodeURIComponent;
  };
  URI.characters = {
    pathname: {
      encode: {
        // RFC3986 2.1: For consistency, URI producers and normalizers should
        // use uppercase hexadecimal digits for all percent-encodings.
        expression: /%(24|26|2B|2C|3B|3D|3A|40)/ig,
        map: {
          // -._~!'()*
          '%24': '$',
          '%26': '&',
          '%2B': '+',
          '%2C': ',',
          '%3B': ';',
          '%3D': '=',
          '%3A': ':',
          '%40': '@'
        }
      },
      decode: {
        expression: /[\/\?#]/g,
        map: {
          '/': '%2F',
          '?': '%3F',
          '#': '%23'
        }
      }
    },
    reserved: {
      encode: {
        // RFC3986 2.1: For consistency, URI producers and normalizers should
        // use uppercase hexadecimal digits for all percent-encodings.
        expression: /%(21|23|24|26|27|28|29|2A|2B|2C|2F|3A|3B|3D|3F|40|5B|5D)/ig,
        map: {
          // gen-delims
          '%3A': ':',
          '%2F': '/',
          '%3F': '?',
          '%23': '#',
          '%5B': '[',
          '%5D': ']',
          '%40': '@',
          // sub-delims
          '%21': '!',
          '%24': '$',
          '%26': '&',
          '%27': '\'',
          '%28': '(',
          '%29': ')',
          '%2A': '*',
          '%2B': '+',
          '%2C': ',',
          '%3B': ';',
          '%3D': '='
        }
      }
    },
    urnpath: {
      // The characters under `encode` are the characters called out by RFC 2141 as being acceptable
      // for usage in a URN. RFC2141 also calls out "-", ".", and "_" as acceptable characters, but
      // these aren't encoded by encodeURIComponent, so we don't have to call them out here. Also
      // note that the colon character is not featured in the encoding map; this is because URI.js
      // gives the colons in URNs semantic meaning as the delimiters of path segements, and so it
      // should not appear unencoded in a segment itself.
      // See also the note above about RFC3986 and capitalalized hex digits.
      encode: {
        expression: /%(21|24|27|28|29|2A|2B|2C|3B|3D|40)/ig,
        map: {
          '%21': '!',
          '%24': '$',
          '%27': '\'',
          '%28': '(',
          '%29': ')',
          '%2A': '*',
          '%2B': '+',
          '%2C': ',',
          '%3B': ';',
          '%3D': '=',
          '%40': '@'
        }
      },
      // These characters are the characters called out by RFC2141 as "reserved" characters that
      // should never appear in a URN, plus the colon character (see note above).
      decode: {
        expression: /[\/\?#:]/g,
        map: {
          '/': '%2F',
          '?': '%3F',
          '#': '%23',
          ':': '%3A'
        }
      }
    }
  };
  URI.encodeQuery = function(string, escapeQuerySpace) {
    var escaped = URI.encode(string + '');
    if (escapeQuerySpace === undefined) {
      escapeQuerySpace = URI.escapeQuerySpace;
    }

    return escapeQuerySpace ? escaped.replace(/%20/g, '+') : escaped;
  };
  URI.decodeQuery = function(string, escapeQuerySpace) {
    string += '';
    if (escapeQuerySpace === undefined) {
      escapeQuerySpace = URI.escapeQuerySpace;
    }

    try {
      return URI.decode(escapeQuerySpace ? string.replace(/\+/g, '%20') : string);
    } catch(e) {
      // we're not going to mess with weird encodings,
      // give up and return the undecoded original string
      // see https://github.com/medialize/URI.js/issues/87
      // see https://github.com/medialize/URI.js/issues/92
      return string;
    }
  };
  // generate encode/decode path functions
  var _parts = {'encode':'encode', 'decode':'decode'};
  var _part;
  var generateAccessor = function(_group, _part) {
    return function(string) {
      try {
        return URI[_part](string + '').replace(URI.characters[_group][_part].expression, function(c) {
          return URI.characters[_group][_part].map[c];
        });
      } catch (e) {
        // we're not going to mess with weird encodings,
        // give up and return the undecoded original string
        // see https://github.com/medialize/URI.js/issues/87
        // see https://github.com/medialize/URI.js/issues/92
        return string;
      }
    };
  };

  for (_part in _parts) {
    URI[_part + 'PathSegment'] = generateAccessor('pathname', _parts[_part]);
    URI[_part + 'UrnPathSegment'] = generateAccessor('urnpath', _parts[_part]);
  }

  var generateSegmentedPathFunction = function(_sep, _codingFuncName, _innerCodingFuncName) {
    return function(string) {
      // Why pass in names of functions, rather than the function objects themselves? The
      // definitions of some functions (but in particular, URI.decode) will occasionally change due
      // to URI.js having ISO8859 and Unicode modes. Passing in the name and getting it will ensure
      // that the functions we use here are "fresh".
      var actualCodingFunc;
      if (!_innerCodingFuncName) {
        actualCodingFunc = URI[_codingFuncName];
      } else {
        actualCodingFunc = function(string) {
          return URI[_codingFuncName](URI[_innerCodingFuncName](string));
        };
      }

      var segments = (string + '').split(_sep);

      for (var i = 0, length = segments.length; i < length; i++) {
        segments[i] = actualCodingFunc(segments[i]);
      }

      return segments.join(_sep);
    };
  };

  // This takes place outside the above loop because we don't want, e.g., encodeUrnPath functions.
  URI.decodePath = generateSegmentedPathFunction('/', 'decodePathSegment');
  URI.decodeUrnPath = generateSegmentedPathFunction(':', 'decodeUrnPathSegment');
  URI.recodePath = generateSegmentedPathFunction('/', 'encodePathSegment', 'decode');
  URI.recodeUrnPath = generateSegmentedPathFunction(':', 'encodeUrnPathSegment', 'decode');

  URI.encodeReserved = generateAccessor('reserved', 'encode');

  URI.parse = function(string, parts) {
    var pos;
    if (!parts) {
      parts = {};
    }
    // [protocol"://"[username[":"password]"@"]hostname[":"port]"/"?][path]["?"querystring]["#"fragment]

    // extract fragment
    pos = string.indexOf('#');
    if (pos > -1) {
      // escaping?
      parts.fragment = string.substring(pos + 1) || null;
      string = string.substring(0, pos);
    }

    // extract query
    pos = string.indexOf('?');
    if (pos > -1) {
      // escaping?
      parts.query = string.substring(pos + 1) || null;
      string = string.substring(0, pos);
    }

    // extract protocol
    if (string.substring(0, 2) === '//') {
      // relative-scheme
      parts.protocol = null;
      string = string.substring(2);
      // extract "user:pass@host:port"
      string = URI.parseAuthority(string, parts);
    } else {
      pos = string.indexOf(':');
      if (pos > -1) {
        parts.protocol = string.substring(0, pos) || null;
        if (parts.protocol && !parts.protocol.match(URI.protocol_expression)) {
          // : may be within the path
          parts.protocol = undefined;
        } else if (string.substring(pos + 1, pos + 3) === '//') {
          string = string.substring(pos + 3);

          // extract "user:pass@host:port"
          string = URI.parseAuthority(string, parts);
        } else {
          string = string.substring(pos + 1);
          parts.urn = true;
        }
      }
    }

    // what's left must be the path
    parts.path = string;

    // and we're done
    return parts;
  };
  URI.parseHost = function(string, parts) {
    // Copy chrome, IE, opera backslash-handling behavior.
    // Back slashes before the query string get converted to forward slashes
    // See: https://github.com/joyent/node/blob/386fd24f49b0e9d1a8a076592a404168faeecc34/lib/url.js#L115-L124
    // See: https://code.google.com/p/chromium/issues/detail?id=25916
    // https://github.com/medialize/URI.js/pull/233
    string = string.replace(/\\/g, '/');

    // extract host:port
    var pos = string.indexOf('/');
    var bracketPos;
    var t;

    if (pos === -1) {
      pos = string.length;
    }

    if (string.charAt(0) === '[') {
      // IPv6 host - http://tools.ietf.org/html/draft-ietf-6man-text-addr-representation-04#section-6
      // I claim most client software breaks on IPv6 anyways. To simplify things, URI only accepts
      // IPv6+port in the format [2001:db8::1]:80 (for the time being)
      bracketPos = string.indexOf(']');
      parts.hostname = string.substring(1, bracketPos) || null;
      parts.port = string.substring(bracketPos + 2, pos) || null;
      if (parts.port === '/') {
        parts.port = null;
      }
    } else {
      var firstColon = string.indexOf(':');
      var firstSlash = string.indexOf('/');
      var nextColon = string.indexOf(':', firstColon + 1);
      if (nextColon !== -1 && (firstSlash === -1 || nextColon < firstSlash)) {
        // IPv6 host contains multiple colons - but no port
        // this notation is actually not allowed by RFC 3986, but we're a liberal parser
        parts.hostname = string.substring(0, pos) || null;
        parts.port = null;
      } else {
        t = string.substring(0, pos).split(':');
        parts.hostname = t[0] || null;
        parts.port = t[1] || null;
      }
    }

    if (parts.hostname && string.substring(pos).charAt(0) !== '/') {
      pos++;
      string = '/' + string;
    }

    return string.substring(pos) || '/';
  };
  URI.parseAuthority = function(string, parts) {
    string = URI.parseUserinfo(string, parts);
    return URI.parseHost(string, parts);
  };
  URI.parseUserinfo = function(string, parts) {
    // extract username:password
    var firstSlash = string.indexOf('/');
    var pos = string.lastIndexOf('@', firstSlash > -1 ? firstSlash : string.length - 1);
    var t;

    // authority@ must come before /path
    if (pos > -1 && (firstSlash === -1 || pos < firstSlash)) {
      t = string.substring(0, pos).split(':');
      parts.username = t[0] ? URI.decode(t[0]) : null;
      t.shift();
      parts.password = t[0] ? URI.decode(t.join(':')) : null;
      string = string.substring(pos + 1);
    } else {
      parts.username = null;
      parts.password = null;
    }

    return string;
  };
  URI.parseQuery = function(string, escapeQuerySpace) {
    if (!string) {
      return {};
    }

    // throw out the funky business - "?"[name"="value"&"]+
    string = string.replace(/&+/g, '&').replace(/^\?*&*|&+$/g, '');

    if (!string) {
      return {};
    }

    var items = {};
    var splits = string.split('&');
    var length = splits.length;
    var v, name, value;

    for (var i = 0; i < length; i++) {
      v = splits[i].split('=');
      name = URI.decodeQuery(v.shift(), escapeQuerySpace);
      // no "=" is null according to http://dvcs.w3.org/hg/url/raw-file/tip/Overview.html#collect-url-parameters
      value = v.length ? URI.decodeQuery(v.join('='), escapeQuerySpace) : null;

      if (hasOwn.call(items, name)) {
        if (typeof items[name] === 'string' || items[name] === null) {
          items[name] = [items[name]];
        }

        items[name].push(value);
      } else {
        items[name] = value;
      }
    }

    return items;
  };

  URI.build = function(parts) {
    var t = '';

    if (parts.protocol) {
      t += parts.protocol + ':';
    }

    if (!parts.urn && (t || parts.hostname)) {
      t += '//';
    }

    t += (URI.buildAuthority(parts) || '');

    if (typeof parts.path === 'string') {
      if (parts.path.charAt(0) !== '/' && typeof parts.hostname === 'string') {
        t += '/';
      }

      t += parts.path;
    }

    if (typeof parts.query === 'string' && parts.query) {
      t += '?' + parts.query;
    }

    if (typeof parts.fragment === 'string' && parts.fragment) {
      t += '#' + parts.fragment;
    }
    return t;
  };
  URI.buildHost = function(parts) {
    var t = '';

    if (!parts.hostname) {
      return '';
    } else if (URI.ip6_expression.test(parts.hostname)) {
      t += '[' + parts.hostname + ']';
    } else {
      t += parts.hostname;
    }

    if (parts.port) {
      t += ':' + parts.port;
    }

    return t;
  };
  URI.buildAuthority = function(parts) {
    return URI.buildUserinfo(parts) + URI.buildHost(parts);
  };
  URI.buildUserinfo = function(parts) {
    var t = '';

    if (parts.username) {
      t += URI.encode(parts.username);

      if (parts.password) {
        t += ':' + URI.encode(parts.password);
      }

      t += '@';
    }

    return t;
  };
  URI.buildQuery = function(data, duplicateQueryParameters, escapeQuerySpace) {
    // according to http://tools.ietf.org/html/rfc3986 or http://labs.apache.org/webarch/uri/rfc/rfc3986.html
    // being »-._~!$&'()*+,;=:@/?« %HEX and alnum are allowed
    // the RFC explicitly states ?/foo being a valid use case, no mention of parameter syntax!
    // URI.js treats the query string as being application/x-www-form-urlencoded
    // see http://www.w3.org/TR/REC-html40/interact/forms.html#form-content-type

    var t = '';
    var unique, key, i, length;
    for (key in data) {
      if (hasOwn.call(data, key) && key) {
        if (isArray(data[key])) {
          unique = {};
          for (i = 0, length = data[key].length; i < length; i++) {
            if (data[key][i] !== undefined && unique[data[key][i] + ''] === undefined) {
              t += '&' + URI.buildQueryParameter(key, data[key][i], escapeQuerySpace);
              if (duplicateQueryParameters !== true) {
                unique[data[key][i] + ''] = true;
              }
            }
          }
        } else if (data[key] !== undefined) {
          t += '&' + URI.buildQueryParameter(key, data[key], escapeQuerySpace);
        }
      }
    }

    return t.substring(1);
  };
  URI.buildQueryParameter = function(name, value, escapeQuerySpace) {
    // http://www.w3.org/TR/REC-html40/interact/forms.html#form-content-type -- application/x-www-form-urlencoded
    // don't append "=" for null values, according to http://dvcs.w3.org/hg/url/raw-file/tip/Overview.html#url-parameter-serialization
    return URI.encodeQuery(name, escapeQuerySpace) + (value !== null ? '=' + URI.encodeQuery(value, escapeQuerySpace) : '');
  };

  URI.addQuery = function(data, name, value) {
    if (typeof name === 'object') {
      for (var key in name) {
        if (hasOwn.call(name, key)) {
          URI.addQuery(data, key, name[key]);
        }
      }
    } else if (typeof name === 'string') {
      if (data[name] === undefined) {
        data[name] = value;
        return;
      } else if (typeof data[name] === 'string') {
        data[name] = [data[name]];
      }

      if (!isArray(value)) {
        value = [value];
      }

      data[name] = (data[name] || []).concat(value);
    } else {
      throw new TypeError('URI.addQuery() accepts an object, string as the name parameter');
    }
  };
  URI.removeQuery = function(data, name, value) {
    var i, length, key;

    if (isArray(name)) {
      for (i = 0, length = name.length; i < length; i++) {
        data[name[i]] = undefined;
      }
    } else if (getType(name) === 'RegExp') {
      for (key in data) {
        if (name.test(key)) {
          data[key] = undefined;
        }
      }
    } else if (typeof name === 'object') {
      for (key in name) {
        if (hasOwn.call(name, key)) {
          URI.removeQuery(data, key, name[key]);
        }
      }
    } else if (typeof name === 'string') {
      if (value !== undefined) {
        if (getType(value) === 'RegExp') {
          if (!isArray(data[name]) && value.test(data[name])) {
            data[name] = undefined;
          } else {
            data[name] = filterArrayValues(data[name], value);
          }
        } else if (data[name] === String(value) && (!isArray(value) || value.length === 1)) {
          data[name] = undefined;
        } else if (isArray(data[name])) {
          data[name] = filterArrayValues(data[name], value);
        }
      } else {
        data[name] = undefined;
      }
    } else {
      throw new TypeError('URI.removeQuery() accepts an object, string, RegExp as the first parameter');
    }
  };
  URI.hasQuery = function(data, name, value, withinArray) {
    if (typeof name === 'object') {
      for (var key in name) {
        if (hasOwn.call(name, key)) {
          if (!URI.hasQuery(data, key, name[key])) {
            return false;
          }
        }
      }

      return true;
    } else if (typeof name !== 'string') {
      throw new TypeError('URI.hasQuery() accepts an object, string as the name parameter');
    }

    switch (getType(value)) {
      case 'Undefined':
        // true if exists (but may be empty)
        return name in data; // data[name] !== undefined;

      case 'Boolean':
        // true if exists and non-empty
        var _booly = Boolean(isArray(data[name]) ? data[name].length : data[name]);
        return value === _booly;

      case 'Function':
        // allow complex comparison
        return !!value(data[name], name, data);

      case 'Array':
        if (!isArray(data[name])) {
          return false;
        }

        var op = withinArray ? arrayContains : arraysEqual;
        return op(data[name], value);

      case 'RegExp':
        if (!isArray(data[name])) {
          return Boolean(data[name] && data[name].match(value));
        }

        if (!withinArray) {
          return false;
        }

        return arrayContains(data[name], value);

      case 'Number':
        value = String(value);
        /* falls through */
      case 'String':
        if (!isArray(data[name])) {
          return data[name] === value;
        }

        if (!withinArray) {
          return false;
        }

        return arrayContains(data[name], value);

      default:
        throw new TypeError('URI.hasQuery() accepts undefined, boolean, string, number, RegExp, Function as the value parameter');
    }
  };


  URI.commonPath = function(one, two) {
    var length = Math.min(one.length, two.length);
    var pos;

    // find first non-matching character
    for (pos = 0; pos < length; pos++) {
      if (one.charAt(pos) !== two.charAt(pos)) {
        pos--;
        break;
      }
    }

    if (pos < 1) {
      return one.charAt(0) === two.charAt(0) && one.charAt(0) === '/' ? '/' : '';
    }

    // revert to last /
    if (one.charAt(pos) !== '/' || two.charAt(pos) !== '/') {
      pos = one.substring(0, pos).lastIndexOf('/');
    }

    return one.substring(0, pos + 1);
  };

  URI.withinString = function(string, callback, options) {
    options || (options = {});
    var _start = options.start || URI.findUri.start;
    var _end = options.end || URI.findUri.end;
    var _trim = options.trim || URI.findUri.trim;
    var _attributeOpen = /[a-z0-9-]=["']?$/i;

    _start.lastIndex = 0;
    while (true) {
      var match = _start.exec(string);
      if (!match) {
        break;
      }

      var start = match.index;
      if (options.ignoreHtml) {
        // attribut(e=["']?$)
        var attributeOpen = string.slice(Math.max(start - 3, 0), start);
        if (attributeOpen && _attributeOpen.test(attributeOpen)) {
          continue;
        }
      }

      var end = start + string.slice(start).search(_end);
      var slice = string.slice(start, end).replace(_trim, '');
      if (options.ignore && options.ignore.test(slice)) {
        continue;
      }

      end = start + slice.length;
      var result = callback(slice, start, end, string);
      string = string.slice(0, start) + result + string.slice(end);
      _start.lastIndex = start + result.length;
    }

    _start.lastIndex = 0;
    return string;
  };

  URI.ensureValidHostname = function(v) {
    // Theoretically URIs allow percent-encoding in Hostnames (according to RFC 3986)
    // they are not part of DNS and therefore ignored by URI.js

    if (v.match(URI.invalid_hostname_characters)) {
      // test punycode
      if (!punycode) {
        throw new TypeError('Hostname "' + v + '" contains characters other than [A-Z0-9.-] and Punycode.js is not available');
      }

      if (punycode.toASCII(v).match(URI.invalid_hostname_characters)) {
        throw new TypeError('Hostname "' + v + '" contains characters other than [A-Z0-9.-]');
      }
    }
  };

  // noConflict
  URI.noConflict = function(removeAll) {
    if (removeAll) {
      var unconflicted = {
        URI: this.noConflict()
      };

      if (root.URITemplate && typeof root.URITemplate.noConflict === 'function') {
        unconflicted.URITemplate = root.URITemplate.noConflict();
      }

      if (root.IPv6 && typeof root.IPv6.noConflict === 'function') {
        unconflicted.IPv6 = root.IPv6.noConflict();
      }

      if (root.SecondLevelDomains && typeof root.SecondLevelDomains.noConflict === 'function') {
        unconflicted.SecondLevelDomains = root.SecondLevelDomains.noConflict();
      }

      return unconflicted;
    } else if (root.URI === this) {
      root.URI = _URI;
    }

    return this;
  };

  p.build = function(deferBuild) {
    if (deferBuild === true) {
      this._deferred_build = true;
    } else if (deferBuild === undefined || this._deferred_build) {
      this._string = URI.build(this._parts);
      this._deferred_build = false;
    }

    return this;
  };

  p.clone = function() {
    return new URI(this);
  };

  p.valueOf = p.toString = function() {
    return this.build(false)._string;
  };


  function generateSimpleAccessor(_part){
    return function(v, build) {
      if (v === undefined) {
        return this._parts[_part] || '';
      } else {
        this._parts[_part] = v || null;
        this.build(!build);
        return this;
      }
    };
  }

  function generatePrefixAccessor(_part, _key){
    return function(v, build) {
      if (v === undefined) {
        return this._parts[_part] || '';
      } else {
        if (v !== null) {
          v = v + '';
          if (v.charAt(0) === _key) {
            v = v.substring(1);
          }
        }

        this._parts[_part] = v;
        this.build(!build);
        return this;
      }
    };
  }

  p.protocol = generateSimpleAccessor('protocol');
  p.username = generateSimpleAccessor('username');
  p.password = generateSimpleAccessor('password');
  p.hostname = generateSimpleAccessor('hostname');
  p.port = generateSimpleAccessor('port');
  p.query = generatePrefixAccessor('query', '?');
  p.fragment = generatePrefixAccessor('fragment', '#');

  p.search = function(v, build) {
    var t = this.query(v, build);
    return typeof t === 'string' && t.length ? ('?' + t) : t;
  };
  p.hash = function(v, build) {
    var t = this.fragment(v, build);
    return typeof t === 'string' && t.length ? ('#' + t) : t;
  };

  p.pathname = function(v, build) {
    if (v === undefined || v === true) {
      var res = this._parts.path || (this._parts.hostname ? '/' : '');
      return v ? (this._parts.urn ? URI.decodeUrnPath : URI.decodePath)(res) : res;
    } else {
      if (this._parts.urn) {
        this._parts.path = v ? URI.recodeUrnPath(v) : '';
      } else {
        this._parts.path = v ? URI.recodePath(v) : '/';
      }
      this.build(!build);
      return this;
    }
  };
  p.path = p.pathname;
  p.href = function(href, build) {
    var key;

    if (href === undefined) {
      return this.toString();
    }

    this._string = '';
    this._parts = URI._parts();

    var _URI = href instanceof URI;
    var _object = typeof href === 'object' && (href.hostname || href.path || href.pathname);
    if (href.nodeName) {
      var attribute = URI.getDomAttribute(href);
      href = href[attribute] || '';
      _object = false;
    }

    // window.location is reported to be an object, but it's not the sort
    // of object we're looking for:
    // * location.protocol ends with a colon
    // * location.query != object.search
    // * location.hash != object.fragment
    // simply serializing the unknown object should do the trick
    // (for location, not for everything...)
    if (!_URI && _object && href.pathname !== undefined) {
      href = href.toString();
    }

    if (typeof href === 'string' || href instanceof String) {
      this._parts = URI.parse(String(href), this._parts);
    } else if (_URI || _object) {
      var src = _URI ? href._parts : href;
      for (key in src) {
        if (hasOwn.call(this._parts, key)) {
          this._parts[key] = src[key];
        }
      }
    } else {
      throw new TypeError('invalid input');
    }

    this.build(!build);
    return this;
  };

  // identification accessors
  p.is = function(what) {
    var ip = false;
    var ip4 = false;
    var ip6 = false;
    var name = false;
    var sld = false;
    var idn = false;
    var punycode = false;
    var relative = !this._parts.urn;

    if (this._parts.hostname) {
      relative = false;
      ip4 = URI.ip4_expression.test(this._parts.hostname);
      ip6 = URI.ip6_expression.test(this._parts.hostname);
      ip = ip4 || ip6;
      name = !ip;
      sld = name && SLD && SLD.has(this._parts.hostname);
      idn = name && URI.idn_expression.test(this._parts.hostname);
      punycode = name && URI.punycode_expression.test(this._parts.hostname);
    }

    switch (what.toLowerCase()) {
      case 'relative':
        return relative;

      case 'absolute':
        return !relative;

      // hostname identification
      case 'domain':
      case 'name':
        return name;

      case 'sld':
        return sld;

      case 'ip':
        return ip;

      case 'ip4':
      case 'ipv4':
      case 'inet4':
        return ip4;

      case 'ip6':
      case 'ipv6':
      case 'inet6':
        return ip6;

      case 'idn':
        return idn;

      case 'url':
        return !this._parts.urn;

      case 'urn':
        return !!this._parts.urn;

      case 'punycode':
        return punycode;
    }

    return null;
  };

  // component specific input validation
  var _protocol = p.protocol;
  var _port = p.port;
  var _hostname = p.hostname;

  p.protocol = function(v, build) {
    if (v !== undefined) {
      if (v) {
        // accept trailing ://
        v = v.replace(/:(\/\/)?$/, '');

        if (!v.match(URI.protocol_expression)) {
          throw new TypeError('Protocol "' + v + '" contains characters other than [A-Z0-9.+-] or doesn\'t start with [A-Z]');
        }
      }
    }
    return _protocol.call(this, v, build);
  };
  p.scheme = p.protocol;
  p.port = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v !== undefined) {
      if (v === 0) {
        v = null;
      }

      if (v) {
        v += '';
        if (v.charAt(0) === ':') {
          v = v.substring(1);
        }

        if (v.match(/[^0-9]/)) {
          throw new TypeError('Port "' + v + '" contains characters other than [0-9]');
        }
      }
    }
    return _port.call(this, v, build);
  };
  p.hostname = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v !== undefined) {
      var x = {};
      var res = URI.parseHost(v, x);
      if (res !== '/') {
        throw new TypeError('Hostname "' + v + '" contains characters other than [A-Z0-9.-]');
      }

      v = x.hostname;
    }
    return _hostname.call(this, v, build);
  };

  // compound accessors
  p.origin = function(v, build) {
    var parts;

    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined) {
      var protocol = this.protocol();
      var authority = this.authority();
      if (!authority) return '';
      return (protocol ? protocol + '://' : '') + this.authority();
    } else {
      var origin = URI(v);
      this
        .protocol(origin.protocol())
        .authority(origin.authority())
        .build(!build);
      return this;
    }
  };
  p.host = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined) {
      return this._parts.hostname ? URI.buildHost(this._parts) : '';
    } else {
      var res = URI.parseHost(v, this._parts);
      if (res !== '/') {
        throw new TypeError('Hostname "' + v + '" contains characters other than [A-Z0-9.-]');
      }

      this.build(!build);
      return this;
    }
  };
  p.authority = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined) {
      return this._parts.hostname ? URI.buildAuthority(this._parts) : '';
    } else {
      var res = URI.parseAuthority(v, this._parts);
      if (res !== '/') {
        throw new TypeError('Hostname "' + v + '" contains characters other than [A-Z0-9.-]');
      }

      this.build(!build);
      return this;
    }
  };
  p.userinfo = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined) {
      if (!this._parts.username) {
        return '';
      }

      var t = URI.buildUserinfo(this._parts);
      return t.substring(0, t.length -1);
    } else {
      if (v[v.length-1] !== '@') {
        v += '@';
      }

      URI.parseUserinfo(v, this._parts);
      this.build(!build);
      return this;
    }
  };
  p.resource = function(v, build) {
    var parts;

    if (v === undefined) {
      return this.path() + this.search() + this.hash();
    }

    parts = URI.parse(v);
    this._parts.path = parts.path;
    this._parts.query = parts.query;
    this._parts.fragment = parts.fragment;
    this.build(!build);
    return this;
  };

  // fraction accessors
  p.subdomain = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    // convenience, return "www" from "www.example.org"
    if (v === undefined) {
      if (!this._parts.hostname || this.is('IP')) {
        return '';
      }

      // grab domain and add another segment
      var end = this._parts.hostname.length - this.domain().length - 1;
      return this._parts.hostname.substring(0, end) || '';
    } else {
      var e = this._parts.hostname.length - this.domain().length;
      var sub = this._parts.hostname.substring(0, e);
      var replace = new RegExp('^' + escapeRegEx(sub));

      if (v && v.charAt(v.length - 1) !== '.') {
        v += '.';
      }

      if (v) {
        URI.ensureValidHostname(v);
      }

      this._parts.hostname = this._parts.hostname.replace(replace, v);
      this.build(!build);
      return this;
    }
  };
  p.domain = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (typeof v === 'boolean') {
      build = v;
      v = undefined;
    }

    // convenience, return "example.org" from "www.example.org"
    if (v === undefined) {
      if (!this._parts.hostname || this.is('IP')) {
        return '';
      }

      // if hostname consists of 1 or 2 segments, it must be the domain
      var t = this._parts.hostname.match(/\./g);
      if (t && t.length < 2) {
        return this._parts.hostname;
      }

      // grab tld and add another segment
      var end = this._parts.hostname.length - this.tld(build).length - 1;
      end = this._parts.hostname.lastIndexOf('.', end -1) + 1;
      return this._parts.hostname.substring(end) || '';
    } else {
      if (!v) {
        throw new TypeError('cannot set domain empty');
      }

      URI.ensureValidHostname(v);

      if (!this._parts.hostname || this.is('IP')) {
        this._parts.hostname = v;
      } else {
        var replace = new RegExp(escapeRegEx(this.domain()) + '$');
        this._parts.hostname = this._parts.hostname.replace(replace, v);
      }

      this.build(!build);
      return this;
    }
  };
  p.tld = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (typeof v === 'boolean') {
      build = v;
      v = undefined;
    }

    // return "org" from "www.example.org"
    if (v === undefined) {
      if (!this._parts.hostname || this.is('IP')) {
        return '';
      }

      var pos = this._parts.hostname.lastIndexOf('.');
      var tld = this._parts.hostname.substring(pos + 1);

      if (build !== true && SLD && SLD.list[tld.toLowerCase()]) {
        return SLD.get(this._parts.hostname) || tld;
      }

      return tld;
    } else {
      var replace;

      if (!v) {
        throw new TypeError('cannot set TLD empty');
      } else if (v.match(/[^a-zA-Z0-9-]/)) {
        if (SLD && SLD.is(v)) {
          replace = new RegExp(escapeRegEx(this.tld()) + '$');
          this._parts.hostname = this._parts.hostname.replace(replace, v);
        } else {
          throw new TypeError('TLD "' + v + '" contains characters other than [A-Z0-9]');
        }
      } else if (!this._parts.hostname || this.is('IP')) {
        throw new ReferenceError('cannot set TLD on non-domain host');
      } else {
        replace = new RegExp(escapeRegEx(this.tld()) + '$');
        this._parts.hostname = this._parts.hostname.replace(replace, v);
      }

      this.build(!build);
      return this;
    }
  };
  p.directory = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined || v === true) {
      if (!this._parts.path && !this._parts.hostname) {
        return '';
      }

      if (this._parts.path === '/') {
        return '/';
      }

      var end = this._parts.path.length - this.filename().length - 1;
      var res = this._parts.path.substring(0, end) || (this._parts.hostname ? '/' : '');

      return v ? URI.decodePath(res) : res;

    } else {
      var e = this._parts.path.length - this.filename().length;
      var directory = this._parts.path.substring(0, e);
      var replace = new RegExp('^' + escapeRegEx(directory));

      // fully qualifier directories begin with a slash
      if (!this.is('relative')) {
        if (!v) {
          v = '/';
        }

        if (v.charAt(0) !== '/') {
          v = '/' + v;
        }
      }

      // directories always end with a slash
      if (v && v.charAt(v.length - 1) !== '/') {
        v += '/';
      }

      v = URI.recodePath(v);
      this._parts.path = this._parts.path.replace(replace, v);
      this.build(!build);
      return this;
    }
  };
  p.filename = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined || v === true) {
      if (!this._parts.path || this._parts.path === '/') {
        return '';
      }

      var pos = this._parts.path.lastIndexOf('/');
      var res = this._parts.path.substring(pos+1);

      return v ? URI.decodePathSegment(res) : res;
    } else {
      var mutatedDirectory = false;

      if (v.charAt(0) === '/') {
        v = v.substring(1);
      }

      if (v.match(/\.?\//)) {
        mutatedDirectory = true;
      }

      var replace = new RegExp(escapeRegEx(this.filename()) + '$');
      v = URI.recodePath(v);
      this._parts.path = this._parts.path.replace(replace, v);

      if (mutatedDirectory) {
        this.normalizePath(build);
      } else {
        this.build(!build);
      }

      return this;
    }
  };
  p.suffix = function(v, build) {
    if (this._parts.urn) {
      return v === undefined ? '' : this;
    }

    if (v === undefined || v === true) {
      if (!this._parts.path || this._parts.path === '/') {
        return '';
      }

      var filename = this.filename();
      var pos = filename.lastIndexOf('.');
      var s, res;

      if (pos === -1) {
        return '';
      }

      // suffix may only contain alnum characters (yup, I made this up.)
      s = filename.substring(pos+1);
      res = (/^[a-z0-9%]+$/i).test(s) ? s : '';
      return v ? URI.decodePathSegment(res) : res;
    } else {
      if (v.charAt(0) === '.') {
        v = v.substring(1);
      }

      var suffix = this.suffix();
      var replace;

      if (!suffix) {
        if (!v) {
          return this;
        }

        this._parts.path += '.' + URI.recodePath(v);
      } else if (!v) {
        replace = new RegExp(escapeRegEx('.' + suffix) + '$');
      } else {
        replace = new RegExp(escapeRegEx(suffix) + '$');
      }

      if (replace) {
        v = URI.recodePath(v);
        this._parts.path = this._parts.path.replace(replace, v);
      }

      this.build(!build);
      return this;
    }
  };
  p.segment = function(segment, v, build) {
    var separator = this._parts.urn ? ':' : '/';
    var path = this.path();
    var absolute = path.substring(0, 1) === '/';
    var segments = path.split(separator);

    if (segment !== undefined && typeof segment !== 'number') {
      build = v;
      v = segment;
      segment = undefined;
    }

    if (segment !== undefined && typeof segment !== 'number') {
      throw new Error('Bad segment "' + segment + '", must be 0-based integer');
    }

    if (absolute) {
      segments.shift();
    }

    if (segment < 0) {
      // allow negative indexes to address from the end
      segment = Math.max(segments.length + segment, 0);
    }

    if (v === undefined) {
      /*jshint laxbreak: true */
      return segment === undefined
        ? segments
        : segments[segment];
      /*jshint laxbreak: false */
    } else if (segment === null || segments[segment] === undefined) {
      if (isArray(v)) {
        segments = [];
        // collapse empty elements within array
        for (var i=0, l=v.length; i < l; i++) {
          if (!v[i].length && (!segments.length || !segments[segments.length -1].length)) {
            continue;
          }

          if (segments.length && !segments[segments.length -1].length) {
            segments.pop();
          }

          segments.push(trimSlashes(v[i]));
        }
      } else if (v || typeof v === 'string') {
        v = trimSlashes(v);
        if (segments[segments.length -1] === '') {
          // empty trailing elements have to be overwritten
          // to prevent results such as /foo//bar
          segments[segments.length -1] = v;
        } else {
          segments.push(v);
        }
      }
    } else {
      if (v) {
        segments[segment] = trimSlashes(v);
      } else {
        segments.splice(segment, 1);
      }
    }

    if (absolute) {
      segments.unshift('');
    }

    return this.path(segments.join(separator), build);
  };
  p.segmentCoded = function(segment, v, build) {
    var segments, i, l;

    if (typeof segment !== 'number') {
      build = v;
      v = segment;
      segment = undefined;
    }

    if (v === undefined) {
      segments = this.segment(segment, v, build);
      if (!isArray(segments)) {
        segments = segments !== undefined ? URI.decode(segments) : undefined;
      } else {
        for (i = 0, l = segments.length; i < l; i++) {
          segments[i] = URI.decode(segments[i]);
        }
      }

      return segments;
    }

    if (!isArray(v)) {
      v = (typeof v === 'string' || v instanceof String) ? URI.encode(v) : v;
    } else {
      for (i = 0, l = v.length; i < l; i++) {
        v[i] = URI.encode(v[i]);
      }
    }

    return this.segment(segment, v, build);
  };

  // mutating query string
  var q = p.query;
  p.query = function(v, build) {
    if (v === true) {
      return URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);
    } else if (typeof v === 'function') {
      var data = URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);
      var result = v.call(this, data);
      this._parts.query = URI.buildQuery(result || data, this._parts.duplicateQueryParameters, this._parts.escapeQuerySpace);
      this.build(!build);
      return this;
    } else if (v !== undefined && typeof v !== 'string') {
      this._parts.query = URI.buildQuery(v, this._parts.duplicateQueryParameters, this._parts.escapeQuerySpace);
      this.build(!build);
      return this;
    } else {
      return q.call(this, v, build);
    }
  };
  p.setQuery = function(name, value, build) {
    var data = URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);

    if (typeof name === 'string' || name instanceof String) {
      data[name] = value !== undefined ? value : null;
    } else if (typeof name === 'object') {
      for (var key in name) {
        if (hasOwn.call(name, key)) {
          data[key] = name[key];
        }
      }
    } else {
      throw new TypeError('URI.addQuery() accepts an object, string as the name parameter');
    }

    this._parts.query = URI.buildQuery(data, this._parts.duplicateQueryParameters, this._parts.escapeQuerySpace);
    if (typeof name !== 'string') {
      build = value;
    }

    this.build(!build);
    return this;
  };
  p.addQuery = function(name, value, build) {
    var data = URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);
    URI.addQuery(data, name, value === undefined ? null : value);
    this._parts.query = URI.buildQuery(data, this._parts.duplicateQueryParameters, this._parts.escapeQuerySpace);
    if (typeof name !== 'string') {
      build = value;
    }

    this.build(!build);
    return this;
  };
  p.removeQuery = function(name, value, build) {
    var data = URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);
    URI.removeQuery(data, name, value);
    this._parts.query = URI.buildQuery(data, this._parts.duplicateQueryParameters, this._parts.escapeQuerySpace);
    if (typeof name !== 'string') {
      build = value;
    }

    this.build(!build);
    return this;
  };
  p.hasQuery = function(name, value, withinArray) {
    var data = URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace);
    return URI.hasQuery(data, name, value, withinArray);
  };
  p.setSearch = p.setQuery;
  p.addSearch = p.addQuery;
  p.removeSearch = p.removeQuery;
  p.hasSearch = p.hasQuery;

  // sanitizing URLs
  p.normalize = function() {
    if (this._parts.urn) {
      return this
        .normalizeProtocol(false)
        .normalizePath(false)
        .normalizeQuery(false)
        .normalizeFragment(false)
        .build();
    }

    return this
      .normalizeProtocol(false)
      .normalizeHostname(false)
      .normalizePort(false)
      .normalizePath(false)
      .normalizeQuery(false)
      .normalizeFragment(false)
      .build();
  };
  p.normalizeProtocol = function(build) {
    if (typeof this._parts.protocol === 'string') {
      this._parts.protocol = this._parts.protocol.toLowerCase();
      this.build(!build);
    }

    return this;
  };
  p.normalizeHostname = function(build) {
    if (this._parts.hostname) {
      if (this.is('IDN') && punycode) {
        this._parts.hostname = punycode.toASCII(this._parts.hostname);
      } else if (this.is('IPv6') && IPv6) {
        this._parts.hostname = IPv6.best(this._parts.hostname);
      }

      this._parts.hostname = this._parts.hostname.toLowerCase();
      this.build(!build);
    }

    return this;
  };
  p.normalizePort = function(build) {
    // remove port of it's the protocol's default
    if (typeof this._parts.protocol === 'string' && this._parts.port === URI.defaultPorts[this._parts.protocol]) {
      this._parts.port = null;
      this.build(!build);
    }

    return this;
  };
  p.normalizePath = function(build) {
    var _path = this._parts.path;
    if (!_path) {
      return this;
    }

    if (this._parts.urn) {
      this._parts.path = URI.recodeUrnPath(this._parts.path);
      this.build(!build);
      return this;
    }

    if (this._parts.path === '/') {
      return this;
    }

    var _was_relative;
    var _leadingParents = '';
    var _parent, _pos;

    // handle relative paths
    if (_path.charAt(0) !== '/') {
      _was_relative = true;
      _path = '/' + _path;
    }

    // handle relative files (as opposed to directories)
    if (_path.slice(-3) === '/..' || _path.slice(-2) === '/.') {
      _path += '/';
    }

    // resolve simples
    _path = _path
      .replace(/(\/(\.\/)+)|(\/\.$)/g, '/')
      .replace(/\/{2,}/g, '/');

    // remember leading parents
    if (_was_relative) {
      _leadingParents = _path.substring(1).match(/^(\.\.\/)+/) || '';
      if (_leadingParents) {
        _leadingParents = _leadingParents[0];
      }
    }

    // resolve parents
    while (true) {
      _parent = _path.indexOf('/..');
      if (_parent === -1) {
        // no more ../ to resolve
        break;
      } else if (_parent === 0) {
        // top level cannot be relative, skip it
        _path = _path.substring(3);
        continue;
      }

      _pos = _path.substring(0, _parent).lastIndexOf('/');
      if (_pos === -1) {
        _pos = _parent;
      }
      _path = _path.substring(0, _pos) + _path.substring(_parent + 3);
    }

    // revert to relative
    if (_was_relative && this.is('relative')) {
      _path = _leadingParents + _path.substring(1);
    }

    _path = URI.recodePath(_path);
    this._parts.path = _path;
    this.build(!build);
    return this;
  };
  p.normalizePathname = p.normalizePath;
  p.normalizeQuery = function(build) {
    if (typeof this._parts.query === 'string') {
      if (!this._parts.query.length) {
        this._parts.query = null;
      } else {
        this.query(URI.parseQuery(this._parts.query, this._parts.escapeQuerySpace));
      }

      this.build(!build);
    }

    return this;
  };
  p.normalizeFragment = function(build) {
    if (!this._parts.fragment) {
      this._parts.fragment = null;
      this.build(!build);
    }

    return this;
  };
  p.normalizeSearch = p.normalizeQuery;
  p.normalizeHash = p.normalizeFragment;

  p.iso8859 = function() {
    // expect unicode input, iso8859 output
    var e = URI.encode;
    var d = URI.decode;

    URI.encode = escape;
    URI.decode = decodeURIComponent;
    try {
      this.normalize();
    } finally {
      URI.encode = e;
      URI.decode = d;
    }
    return this;
  };

  p.unicode = function() {
    // expect iso8859 input, unicode output
    var e = URI.encode;
    var d = URI.decode;

    URI.encode = strictEncodeURIComponent;
    URI.decode = unescape;
    try {
      this.normalize();
    } finally {
      URI.encode = e;
      URI.decode = d;
    }
    return this;
  };

  p.readable = function() {
    var uri = this.clone();
    // removing username, password, because they shouldn't be displayed according to RFC 3986
    uri.username('').password('').normalize();
    var t = '';
    if (uri._parts.protocol) {
      t += uri._parts.protocol + '://';
    }

    if (uri._parts.hostname) {
      if (uri.is('punycode') && punycode) {
        t += punycode.toUnicode(uri._parts.hostname);
        if (uri._parts.port) {
          t += ':' + uri._parts.port;
        }
      } else {
        t += uri.host();
      }
    }

    if (uri._parts.hostname && uri._parts.path && uri._parts.path.charAt(0) !== '/') {
      t += '/';
    }

    t += uri.path(true);
    if (uri._parts.query) {
      var q = '';
      for (var i = 0, qp = uri._parts.query.split('&'), l = qp.length; i < l; i++) {
        var kv = (qp[i] || '').split('=');
        q += '&' + URI.decodeQuery(kv[0], this._parts.escapeQuerySpace)
          .replace(/&/g, '%26');

        if (kv[1] !== undefined) {
          q += '=' + URI.decodeQuery(kv[1], this._parts.escapeQuerySpace)
            .replace(/&/g, '%26');
        }
      }
      t += '?' + q.substring(1);
    }

    t += URI.decodeQuery(uri.hash(), true);
    return t;
  };

  // resolving relative and absolute URLs
  p.absoluteTo = function(base) {
    var resolved = this.clone();
    var properties = ['protocol', 'username', 'password', 'hostname', 'port'];
    var basedir, i, p;

    if (this._parts.urn) {
      throw new Error('URNs do not have any generally defined hierarchical components');
    }

    if (!(base instanceof URI)) {
      base = new URI(base);
    }

    if (!resolved._parts.protocol) {
      resolved._parts.protocol = base._parts.protocol;
    }

    if (this._parts.hostname) {
      return resolved;
    }

    for (i = 0; (p = properties[i]); i++) {
      resolved._parts[p] = base._parts[p];
    }

    if (!resolved._parts.path) {
      resolved._parts.path = base._parts.path;
      if (!resolved._parts.query) {
        resolved._parts.query = base._parts.query;
      }
    } else if (resolved._parts.path.substring(-2) === '..') {
      resolved._parts.path += '/';
    }

    if (resolved.path().charAt(0) !== '/') {
      basedir = base.directory();
      basedir = basedir ? basedir : base.path().indexOf('/') === 0 ? '/' : '';
      resolved._parts.path = (basedir ? (basedir + '/') : '') + resolved._parts.path;
      resolved.normalizePath();
    }

    resolved.build();
    return resolved;
  };
  p.relativeTo = function(base) {
    var relative = this.clone().normalize();
    var relativeParts, baseParts, common, relativePath, basePath;

    if (relative._parts.urn) {
      throw new Error('URNs do not have any generally defined hierarchical components');
    }

    base = new URI(base).normalize();
    relativeParts = relative._parts;
    baseParts = base._parts;
    relativePath = relative.path();
    basePath = base.path();

    if (relativePath.charAt(0) !== '/') {
      throw new Error('URI is already relative');
    }

    if (basePath.charAt(0) !== '/') {
      throw new Error('Cannot calculate a URI relative to another relative URI');
    }

    if (relativeParts.protocol === baseParts.protocol) {
      relativeParts.protocol = null;
    }

    if (relativeParts.username !== baseParts.username || relativeParts.password !== baseParts.password) {
      return relative.build();
    }

    if (relativeParts.protocol !== null || relativeParts.username !== null || relativeParts.password !== null) {
      return relative.build();
    }

    if (relativeParts.hostname === baseParts.hostname && relativeParts.port === baseParts.port) {
      relativeParts.hostname = null;
      relativeParts.port = null;
    } else {
      return relative.build();
    }

    if (relativePath === basePath) {
      relativeParts.path = '';
      return relative.build();
    }

    // determine common sub path
    common = URI.commonPath(relativePath, basePath);

    // If the paths have nothing in common, return a relative URL with the absolute path.
    if (!common) {
      return relative.build();
    }

    var parents = baseParts.path
      .substring(common.length)
      .replace(/[^\/]*$/, '')
      .replace(/.*?\//g, '../');

    relativeParts.path = (parents + relativeParts.path.substring(common.length)) || './';

    return relative.build();
  };

  // comparing URIs
  p.equals = function(uri) {
    var one = this.clone();
    var two = new URI(uri);
    var one_map = {};
    var two_map = {};
    var checked = {};
    var one_query, two_query, key;

    one.normalize();
    two.normalize();

    // exact match
    if (one.toString() === two.toString()) {
      return true;
    }

    // extract query string
    one_query = one.query();
    two_query = two.query();
    one.query('');
    two.query('');

    // definitely not equal if not even non-query parts match
    if (one.toString() !== two.toString()) {
      return false;
    }

    // query parameters have the same length, even if they're permuted
    if (one_query.length !== two_query.length) {
      return false;
    }

    one_map = URI.parseQuery(one_query, this._parts.escapeQuerySpace);
    two_map = URI.parseQuery(two_query, this._parts.escapeQuerySpace);

    for (key in one_map) {
      if (hasOwn.call(one_map, key)) {
        if (!isArray(one_map[key])) {
          if (one_map[key] !== two_map[key]) {
            return false;
          }
        } else if (!arraysEqual(one_map[key], two_map[key])) {
          return false;
        }

        checked[key] = true;
      }
    }

    for (key in two_map) {
      if (hasOwn.call(two_map, key)) {
        if (!checked[key]) {
          // two contains a parameter not present in one
          return false;
        }
      }
    }

    return true;
  };

  // state
  p.duplicateQueryParameters = function(v) {
    this._parts.duplicateQueryParameters = !!v;
    return this;
  };

  p.escapeQuerySpace = function(v) {
    this._parts.escapeQuerySpace = !!v;
    return this;
  };

  return URI;
}));

},{"./IPv6":1,"./SecondLevelDomains":2,"./punycode":4}],4:[function(require,module,exports){
(function (global){
/*! http://mths.be/punycode v1.2.3 by @mathias */
;(function(root) {

	/** Detect free variables */
	var freeExports = typeof exports == 'object' && exports;
	var freeModule = typeof module == 'object' && module &&
		module.exports == freeExports && module;
	var freeGlobal = typeof global == 'object' && global;
	if (freeGlobal.global === freeGlobal || freeGlobal.window === freeGlobal) {
		root = freeGlobal;
	}

	/**
	 * The `punycode` object.
	 * @name punycode
	 * @type Object
	 */
	var punycode,

	/** Highest positive signed 32-bit float value */
	maxInt = 2147483647, // aka. 0x7FFFFFFF or 2^31-1

	/** Bootstring parameters */
	base = 36,
	tMin = 1,
	tMax = 26,
	skew = 38,
	damp = 700,
	initialBias = 72,
	initialN = 128, // 0x80
	delimiter = '-', // '\x2D'

	/** Regular expressions */
	regexPunycode = /^xn--/,
	regexNonASCII = /[^ -~]/, // unprintable ASCII chars + non-ASCII chars
	regexSeparators = /\x2E|\u3002|\uFF0E|\uFF61/g, // RFC 3490 separators

	/** Error messages */
	errors = {
		'overflow': 'Overflow: input needs wider integers to process',
		'not-basic': 'Illegal input >= 0x80 (not a basic code point)',
		'invalid-input': 'Invalid input'
	},

	/** Convenience shortcuts */
	baseMinusTMin = base - tMin,
	floor = Math.floor,
	stringFromCharCode = String.fromCharCode,

	/** Temporary variable */
	key;

	/*--------------------------------------------------------------------------*/

	/**
	 * A generic error utility function.
	 * @private
	 * @param {String} type The error type.
	 * @returns {Error} Throws a `RangeError` with the applicable error message.
	 */
	function error(type) {
		throw RangeError(errors[type]);
	}

	/**
	 * A generic `Array#map` utility function.
	 * @private
	 * @param {Array} array The array to iterate over.
	 * @param {Function} callback The function that gets called for every array
	 * item.
	 * @returns {Array} A new array of values returned by the callback function.
	 */
	function map(array, fn) {
		var length = array.length;
		while (length--) {
			array[length] = fn(array[length]);
		}
		return array;
	}

	/**
	 * A simple `Array#map`-like wrapper to work with domain name strings.
	 * @private
	 * @param {String} domain The domain name.
	 * @param {Function} callback The function that gets called for every
	 * character.
	 * @returns {Array} A new string of characters returned by the callback
	 * function.
	 */
	function mapDomain(string, fn) {
		return map(string.split(regexSeparators), fn).join('.');
	}

	/**
	 * Creates an array containing the numeric code points of each Unicode
	 * character in the string. While JavaScript uses UCS-2 internally,
	 * this function will convert a pair of surrogate halves (each of which
	 * UCS-2 exposes as separate characters) into a single code point,
	 * matching UTF-16.
	 * @see `punycode.ucs2.encode`
	 * @see <http://mathiasbynens.be/notes/javascript-encoding>
	 * @memberOf punycode.ucs2
	 * @name decode
	 * @param {String} string The Unicode input string (UCS-2).
	 * @returns {Array} The new array of code points.
	 */
	function ucs2decode(string) {
		var output = [],
		    counter = 0,
		    length = string.length,
		    value,
		    extra;
		while (counter < length) {
			value = string.charCodeAt(counter++);
			if (value >= 0xD800 && value <= 0xDBFF && counter < length) {
				// high surrogate, and there is a next character
				extra = string.charCodeAt(counter++);
				if ((extra & 0xFC00) == 0xDC00) { // low surrogate
					output.push(((value & 0x3FF) << 10) + (extra & 0x3FF) + 0x10000);
				} else {
					// unmatched surrogate; only append this code unit, in case the next
					// code unit is the high surrogate of a surrogate pair
					output.push(value);
					counter--;
				}
			} else {
				output.push(value);
			}
		}
		return output;
	}

	/**
	 * Creates a string based on an array of numeric code points.
	 * @see `punycode.ucs2.decode`
	 * @memberOf punycode.ucs2
	 * @name encode
	 * @param {Array} codePoints The array of numeric code points.
	 * @returns {String} The new Unicode string (UCS-2).
	 */
	function ucs2encode(array) {
		return map(array, function(value) {
			var output = '';
			if (value > 0xFFFF) {
				value -= 0x10000;
				output += stringFromCharCode(value >>> 10 & 0x3FF | 0xD800);
				value = 0xDC00 | value & 0x3FF;
			}
			output += stringFromCharCode(value);
			return output;
		}).join('');
	}

	/**
	 * Converts a basic code point into a digit/integer.
	 * @see `digitToBasic()`
	 * @private
	 * @param {Number} codePoint The basic numeric code point value.
	 * @returns {Number} The numeric value of a basic code point (for use in
	 * representing integers) in the range `0` to `base - 1`, or `base` if
	 * the code point does not represent a value.
	 */
	function basicToDigit(codePoint) {
		if (codePoint - 48 < 10) {
			return codePoint - 22;
		}
		if (codePoint - 65 < 26) {
			return codePoint - 65;
		}
		if (codePoint - 97 < 26) {
			return codePoint - 97;
		}
		return base;
	}

	/**
	 * Converts a digit/integer into a basic code point.
	 * @see `basicToDigit()`
	 * @private
	 * @param {Number} digit The numeric value of a basic code point.
	 * @returns {Number} The basic code point whose value (when used for
	 * representing integers) is `digit`, which needs to be in the range
	 * `0` to `base - 1`. If `flag` is non-zero, the uppercase form is
	 * used; else, the lowercase form is used. The behavior is undefined
	 * if `flag` is non-zero and `digit` has no uppercase form.
	 */
	function digitToBasic(digit, flag) {
		//  0..25 map to ASCII a..z or A..Z
		// 26..35 map to ASCII 0..9
		return digit + 22 + 75 * (digit < 26) - ((flag != 0) << 5);
	}

	/**
	 * Bias adaptation function as per section 3.4 of RFC 3492.
	 * http://tools.ietf.org/html/rfc3492#section-3.4
	 * @private
	 */
	function adapt(delta, numPoints, firstTime) {
		var k = 0;
		delta = firstTime ? floor(delta / damp) : delta >> 1;
		delta += floor(delta / numPoints);
		for (/* no initialization */; delta > baseMinusTMin * tMax >> 1; k += base) {
			delta = floor(delta / baseMinusTMin);
		}
		return floor(k + (baseMinusTMin + 1) * delta / (delta + skew));
	}

	/**
	 * Converts a Punycode string of ASCII-only symbols to a string of Unicode
	 * symbols.
	 * @memberOf punycode
	 * @param {String} input The Punycode string of ASCII-only symbols.
	 * @returns {String} The resulting string of Unicode symbols.
	 */
	function decode(input) {
		// Don't use UCS-2
		var output = [],
		    inputLength = input.length,
		    out,
		    i = 0,
		    n = initialN,
		    bias = initialBias,
		    basic,
		    j,
		    index,
		    oldi,
		    w,
		    k,
		    digit,
		    t,
		    length,
		    /** Cached calculation results */
		    baseMinusT;

		// Handle the basic code points: let `basic` be the number of input code
		// points before the last delimiter, or `0` if there is none, then copy
		// the first basic code points to the output.

		basic = input.lastIndexOf(delimiter);
		if (basic < 0) {
			basic = 0;
		}

		for (j = 0; j < basic; ++j) {
			// if it's not a basic code point
			if (input.charCodeAt(j) >= 0x80) {
				error('not-basic');
			}
			output.push(input.charCodeAt(j));
		}

		// Main decoding loop: start just after the last delimiter if any basic code
		// points were copied; start at the beginning otherwise.

		for (index = basic > 0 ? basic + 1 : 0; index < inputLength; /* no final expression */) {

			// `index` is the index of the next character to be consumed.
			// Decode a generalized variable-length integer into `delta`,
			// which gets added to `i`. The overflow checking is easier
			// if we increase `i` as we go, then subtract off its starting
			// value at the end to obtain `delta`.
			for (oldi = i, w = 1, k = base; /* no condition */; k += base) {

				if (index >= inputLength) {
					error('invalid-input');
				}

				digit = basicToDigit(input.charCodeAt(index++));

				if (digit >= base || digit > floor((maxInt - i) / w)) {
					error('overflow');
				}

				i += digit * w;
				t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias);

				if (digit < t) {
					break;
				}

				baseMinusT = base - t;
				if (w > floor(maxInt / baseMinusT)) {
					error('overflow');
				}

				w *= baseMinusT;

			}

			out = output.length + 1;
			bias = adapt(i - oldi, out, oldi == 0);

			// `i` was supposed to wrap around from `out` to `0`,
			// incrementing `n` each time, so we'll fix that now:
			if (floor(i / out) > maxInt - n) {
				error('overflow');
			}

			n += floor(i / out);
			i %= out;

			// Insert `n` at position `i` of the output
			output.splice(i++, 0, n);

		}

		return ucs2encode(output);
	}

	/**
	 * Converts a string of Unicode symbols to a Punycode string of ASCII-only
	 * symbols.
	 * @memberOf punycode
	 * @param {String} input The string of Unicode symbols.
	 * @returns {String} The resulting Punycode string of ASCII-only symbols.
	 */
	function encode(input) {
		var n,
		    delta,
		    handledCPCount,
		    basicLength,
		    bias,
		    j,
		    m,
		    q,
		    k,
		    t,
		    currentValue,
		    output = [],
		    /** `inputLength` will hold the number of code points in `input`. */
		    inputLength,
		    /** Cached calculation results */
		    handledCPCountPlusOne,
		    baseMinusT,
		    qMinusT;

		// Convert the input in UCS-2 to Unicode
		input = ucs2decode(input);

		// Cache the length
		inputLength = input.length;

		// Initialize the state
		n = initialN;
		delta = 0;
		bias = initialBias;

		// Handle the basic code points
		for (j = 0; j < inputLength; ++j) {
			currentValue = input[j];
			if (currentValue < 0x80) {
				output.push(stringFromCharCode(currentValue));
			}
		}

		handledCPCount = basicLength = output.length;

		// `handledCPCount` is the number of code points that have been handled;
		// `basicLength` is the number of basic code points.

		// Finish the basic string - if it is not empty - with a delimiter
		if (basicLength) {
			output.push(delimiter);
		}

		// Main encoding loop:
		while (handledCPCount < inputLength) {

			// All non-basic code points < n have been handled already. Find the next
			// larger one:
			for (m = maxInt, j = 0; j < inputLength; ++j) {
				currentValue = input[j];
				if (currentValue >= n && currentValue < m) {
					m = currentValue;
				}
			}

			// Increase `delta` enough to advance the decoder's <n,i> state to <m,0>,
			// but guard against overflow
			handledCPCountPlusOne = handledCPCount + 1;
			if (m - n > floor((maxInt - delta) / handledCPCountPlusOne)) {
				error('overflow');
			}

			delta += (m - n) * handledCPCountPlusOne;
			n = m;

			for (j = 0; j < inputLength; ++j) {
				currentValue = input[j];

				if (currentValue < n && ++delta > maxInt) {
					error('overflow');
				}

				if (currentValue == n) {
					// Represent delta as a generalized variable-length integer
					for (q = delta, k = base; /* no condition */; k += base) {
						t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias);
						if (q < t) {
							break;
						}
						qMinusT = q - t;
						baseMinusT = base - t;
						output.push(
							stringFromCharCode(digitToBasic(t + qMinusT % baseMinusT, 0))
						);
						q = floor(qMinusT / baseMinusT);
					}

					output.push(stringFromCharCode(digitToBasic(q, 0)));
					bias = adapt(delta, handledCPCountPlusOne, handledCPCount == basicLength);
					delta = 0;
					++handledCPCount;
				}
			}

			++delta;
			++n;

		}
		return output.join('');
	}

	/**
	 * Converts a Punycode string representing a domain name to Unicode. Only the
	 * Punycoded parts of the domain name will be converted, i.e. it doesn't
	 * matter if you call it on a string that has already been converted to
	 * Unicode.
	 * @memberOf punycode
	 * @param {String} domain The Punycode domain name to convert to Unicode.
	 * @returns {String} The Unicode representation of the given Punycode
	 * string.
	 */
	function toUnicode(domain) {
		return mapDomain(domain, function(string) {
			return regexPunycode.test(string)
				? decode(string.slice(4).toLowerCase())
				: string;
		});
	}

	/**
	 * Converts a Unicode string representing a domain name to Punycode. Only the
	 * non-ASCII parts of the domain name will be converted, i.e. it doesn't
	 * matter if you call it with a domain that's already in ASCII.
	 * @memberOf punycode
	 * @param {String} domain The domain name to convert, as a Unicode string.
	 * @returns {String} The Punycode representation of the given domain name.
	 */
	function toASCII(domain) {
		return mapDomain(domain, function(string) {
			return regexNonASCII.test(string)
				? 'xn--' + encode(string)
				: string;
		});
	}

	/*--------------------------------------------------------------------------*/

	/** Define the public API */
	punycode = {
		/**
		 * A string representing the current Punycode.js version number.
		 * @memberOf punycode
		 * @type String
		 */
		'version': '1.2.3',
		/**
		 * An object of methods to convert from JavaScript's internal character
		 * representation (UCS-2) to Unicode code points, and back.
		 * @see <http://mathiasbynens.be/notes/javascript-encoding>
		 * @memberOf punycode
		 * @type Object
		 */
		'ucs2': {
			'decode': ucs2decode,
			'encode': ucs2encode
		},
		'decode': decode,
		'encode': encode,
		'toASCII': toASCII,
		'toUnicode': toUnicode
	};

	/** Expose `punycode` */
	// Some AMD build optimizers, like r.js, check for specific condition patterns
	// like the following:
	if (
		typeof define == 'function' &&
		typeof define.amd == 'object' &&
		define.amd
	) {
		define(function() {
			return punycode;
		});
	}	else if (freeExports && !freeExports.nodeType) {
		if (freeModule) { // in Node.js or RingoJS v0.8.0+
			freeModule.exports = punycode;
		} else { // in Narwhal or RingoJS v0.7.0-
			for (key in punycode) {
				punycode.hasOwnProperty(key) && (freeExports[key] = punycode[key]);
			}
		}
	} else { // in Rhino or a web browser
		root.punycode = punycode;
	}

}(this));

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})

},{}],5:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

var _helpersEvent = require('./helpers/event');

var _helpersEvent2 = _interopRequireDefault(_helpersEvent);

var _helpersMessageEvent = require('./helpers/message-event');

var _helpersMessageEvent2 = _interopRequireDefault(_helpersMessageEvent);

var _helpersCloseEvent = require('./helpers/close-event');

var _helpersCloseEvent2 = _interopRequireDefault(_helpersCloseEvent);

/*
* Creates an Event object and extends it to allow full modification of
* its properties.
*
* @param {object} config - within config you will need to pass type and optionally target
*/
function createEvent(config) {
  var type = config.type;
  var target = config.target;

  var eventObject = new _helpersEvent2['default'](type);

  if (target) {
    eventObject.target = target;
    eventObject.srcElement = target;
    eventObject.currentTarget = target;
  }

  return eventObject;
}

/*
* Creates a MessageEvent object and extends it to allow full modification of
* its properties.
*
* @param {object} config - within config you will need to pass type, origin, data and optionally target
*/
function createMessageEvent(config) {
  var type = config.type;
  var origin = config.origin;
  var data = config.data;
  var target = config.target;

  var messageEvent = new _helpersMessageEvent2['default'](type, {
    data: data,
    origin: origin
  });

  if (target) {
    messageEvent.target = target;
    messageEvent.srcElement = target;
    messageEvent.currentTarget = target;
  }

  return messageEvent;
}

/*
* Creates a CloseEvent object and extends it to allow full modification of
* its properties.
*
* @param {object} config - within config you will need to pass type and optionally target, code, and reason
*/
function createCloseEvent(config) {
  var code = config.code;
  var reason = config.reason;
  var type = config.type;
  var target = config.target;
  var wasClean = config.wasClean;

  if (!wasClean) {
    wasClean = code === 1000;
  }

  var closeEvent = new _helpersCloseEvent2['default'](type, {
    code: code,
    reason: reason,
    wasClean: wasClean
  });

  if (target) {
    closeEvent.target = target;
    closeEvent.srcElement = target;
    closeEvent.currentTarget = target;
  }

  return closeEvent;
}

exports.createEvent = createEvent;
exports.createMessageEvent = createMessageEvent;
exports.createCloseEvent = createCloseEvent;
},{"./helpers/close-event":9,"./helpers/event":12,"./helpers/message-event":13}],6:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

var _helpersArrayHelpers = require('./helpers/array-helpers');

/*
* EventTarget is an interface implemented by objects that can
* receive events and may have listeners for them.
*
* https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
*/

var EventTarget = (function () {
  function EventTarget() {
    _classCallCheck(this, EventTarget);

    this.listeners = {};
  }

  /*
  * Ties a listener function to an event type which can later be invoked via the
  * dispatchEvent method.
  *
  * @param {string} type - the type of event (ie: 'open', 'message', etc.)
  * @param {function} listener - the callback function to invoke whenever an event is dispatched matching the given type
  * @param {boolean} useCapture - N/A TODO: implement useCapture functionality
  */

  _createClass(EventTarget, [{
    key: 'addEventListener',
    value: function addEventListener(type, listener /* , useCapture */) {
      if (typeof listener === 'function') {
        if (!Array.isArray(this.listeners[type])) {
          this.listeners[type] = [];
        }

        // Only add the same function once
        if ((0, _helpersArrayHelpers.filter)(this.listeners[type], function (item) {
          return item === listener;
        }).length === 0) {
          this.listeners[type].push(listener);
        }
      }
    }

    /*
    * Removes the listener so it will no longer be invoked via the dispatchEvent method.
    *
    * @param {string} type - the type of event (ie: 'open', 'message', etc.)
    * @param {function} listener - the callback function to invoke whenever an event is dispatched matching the given type
    * @param {boolean} useCapture - N/A TODO: implement useCapture functionality
    */
  }, {
    key: 'removeEventListener',
    value: function removeEventListener(type, removingListener /* , useCapture */) {
      var arrayOfListeners = this.listeners[type];
      this.listeners[type] = (0, _helpersArrayHelpers.reject)(arrayOfListeners, function (listener) {
        return listener === removingListener;
      });
    }

    /*
    * Invokes all listener functions that are listening to the given event.type property. Each
    * listener will be passed the event as the first argument.
    *
    * @param {object} event - event object which will be passed to all listeners of the event.type property
    */
  }, {
    key: 'dispatchEvent',
    value: function dispatchEvent(event) {
      var _this = this;

      for (var _len = arguments.length, customArguments = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        customArguments[_key - 1] = arguments[_key];
      }

      var eventName = event.type;
      var listeners = this.listeners[eventName];

      if (!Array.isArray(listeners)) {
        return false;
      }

      listeners.forEach(function (listener) {
        if (customArguments.length > 0) {
          listener.apply(_this, customArguments);
        } else {
          listener.call(_this, event);
        }
      });
    }
  }]);

  return EventTarget;
})();

exports['default'] = EventTarget;
module.exports = exports['default'];
},{"./helpers/array-helpers":7}],7:[function(require,module,exports){
"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.reject = reject;
exports.filter = filter;

function reject(array, callback) {
  var results = [];
  array.forEach(function (itemInArray) {
    if (!callback(itemInArray)) {
      results.push(itemInArray);
    }
  });

  return results;
}

function filter(array, callback) {
  var results = [];
  array.forEach(function (itemInArray) {
    if (callback(itemInArray)) {
      results.push(itemInArray);
    }
  });

  return results;
}
},{}],8:[function(require,module,exports){
/*
* https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent
*/
"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
var codes = {
  CLOSE_NORMAL: 1000,
  CLOSE_GOING_AWAY: 1001,
  CLOSE_PROTOCOL_ERROR: 1002,
  CLOSE_UNSUPPORTED: 1003,
  CLOSE_NO_STATUS: 1005,
  CLOSE_ABNORMAL: 1006,
  CLOSE_TOO_LARGE: 1009
};

exports["default"] = codes;
module.exports = exports["default"];
},{}],9:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _get = function get(_x2, _x3, _x4) { var _again = true; _function: while (_again) { var object = _x2, property = _x3, receiver = _x4; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x2 = parent; _x3 = property; _x4 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _eventPrototype = require('./event-prototype');

var _eventPrototype2 = _interopRequireDefault(_eventPrototype);

var CloseEvent = (function (_EventPrototype) {
  _inherits(CloseEvent, _EventPrototype);

  function CloseEvent(type) {
    var eventInitConfig = arguments.length <= 1 || arguments[1] === undefined ? {} : arguments[1];

    _classCallCheck(this, CloseEvent);

    _get(Object.getPrototypeOf(CloseEvent.prototype), 'constructor', this).call(this);

    if (!type) {
      throw new TypeError('Failed to construct \'CloseEvent\': 1 argument required, but only 0 present.');
    }

    if (typeof eventInitConfig !== 'object') {
      throw new TypeError('Failed to construct \'CloseEvent\': parameter 2 (\'eventInitDict\') is not an object');
    }

    var bubbles = eventInitConfig.bubbles;
    var cancelable = eventInitConfig.cancelable;
    var code = eventInitConfig.code;
    var reason = eventInitConfig.reason;
    var wasClean = eventInitConfig.wasClean;

    this.type = String(type);
    this.timeStamp = Date.now();
    this.target = null;
    this.srcElement = null;
    this.returnValue = true;
    this.isTrusted = false;
    this.eventPhase = 0;
    this.defaultPrevented = false;
    this.currentTarget = null;
    this.cancelable = cancelable ? Boolean(cancelable) : false;
    this.canncelBubble = false;
    this.bubbles = bubbles ? Boolean(bubbles) : false;
    this.code = typeof code === 'number' ? Number(code) : 0;
    this.reason = reason ? String(reason) : '';
    this.wasClean = wasClean ? Boolean(wasClean) : false;
  }

  return CloseEvent;
})(_eventPrototype2['default']);

exports['default'] = CloseEvent;
module.exports = exports['default'];
},{"./event-prototype":11}],10:[function(require,module,exports){
/*
* This delay allows the thread to finish assigning its on* methods
* before invoking the delay callback. This is purely a timing hack.
* http://geekabyte.blogspot.com/2014/01/javascript-effect-of-setting-settimeout.html
*
* @param {callback: function} the callback which will be invoked after the timeout
* @parma {context: object} the context in which to invoke the function
*/
"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
function delay(callback, context) {
  setTimeout(function timeout(timeoutContext) {
    callback.call(timeoutContext);
  }, 4, context);
}

exports["default"] = delay;
module.exports = exports["default"];
},{}],11:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

var EventPrototype = (function () {
  function EventPrototype() {
    _classCallCheck(this, EventPrototype);
  }

  _createClass(EventPrototype, [{
    key: 'stopPropagation',

    // Noops
    value: function stopPropagation() {}
  }, {
    key: 'stopImmediatePropagation',
    value: function stopImmediatePropagation() {}

    // if no arguments are passed then the type is set to "undefined" on
    // chrome and safari.
  }, {
    key: 'initEvent',
    value: function initEvent() {
      var type = arguments.length <= 0 || arguments[0] === undefined ? 'undefined' : arguments[0];
      var bubbles = arguments.length <= 1 || arguments[1] === undefined ? false : arguments[1];
      var cancelable = arguments.length <= 2 || arguments[2] === undefined ? false : arguments[2];

      Object.assign(this, {
        type: String(type),
        bubbles: Boolean(bubbles),
        cancelable: Boolean(cancelable)
      });
    }
  }]);

  return EventPrototype;
})();

exports['default'] = EventPrototype;
module.exports = exports['default'];
},{}],12:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _get = function get(_x2, _x3, _x4) { var _again = true; _function: while (_again) { var object = _x2, property = _x3, receiver = _x4; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x2 = parent; _x3 = property; _x4 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _eventPrototype = require('./event-prototype');

var _eventPrototype2 = _interopRequireDefault(_eventPrototype);

var Event = (function (_EventPrototype) {
  _inherits(Event, _EventPrototype);

  function Event(type) {
    var eventInitConfig = arguments.length <= 1 || arguments[1] === undefined ? {} : arguments[1];

    _classCallCheck(this, Event);

    _get(Object.getPrototypeOf(Event.prototype), 'constructor', this).call(this);

    if (!type) {
      throw new TypeError('Failed to construct \'Event\': 1 argument required, but only 0 present.');
    }

    if (typeof eventInitConfig !== 'object') {
      throw new TypeError('Failed to construct \'Event\': parameter 2 (\'eventInitDict\') is not an object');
    }

    var bubbles = eventInitConfig.bubbles;
    var cancelable = eventInitConfig.cancelable;

    this.type = String(type);
    this.timeStamp = Date.now();
    this.target = null;
    this.srcElement = null;
    this.returnValue = true;
    this.isTrusted = false;
    this.eventPhase = 0;
    this.defaultPrevented = false;
    this.currentTarget = null;
    this.cancelable = cancelable ? Boolean(cancelable) : false;
    this.canncelBubble = false;
    this.bubbles = bubbles ? Boolean(bubbles) : false;
  }

  return Event;
})(_eventPrototype2['default']);

exports['default'] = Event;
module.exports = exports['default'];
},{"./event-prototype":11}],13:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _get = function get(_x2, _x3, _x4) { var _again = true; _function: while (_again) { var object = _x2, property = _x3, receiver = _x4; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x2 = parent; _x3 = property; _x4 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _eventPrototype = require('./event-prototype');

var _eventPrototype2 = _interopRequireDefault(_eventPrototype);

var MessageEvent = (function (_EventPrototype) {
  _inherits(MessageEvent, _EventPrototype);

  function MessageEvent(type) {
    var eventInitConfig = arguments.length <= 1 || arguments[1] === undefined ? {} : arguments[1];

    _classCallCheck(this, MessageEvent);

    _get(Object.getPrototypeOf(MessageEvent.prototype), 'constructor', this).call(this);

    if (!type) {
      throw new TypeError('Failed to construct \'MessageEvent\': 1 argument required, but only 0 present.');
    }

    if (typeof eventInitConfig !== 'object') {
      throw new TypeError('Failed to construct \'MessageEvent\': parameter 2 (\'eventInitDict\') is not an object');
    }

    var bubbles = eventInitConfig.bubbles;
    var cancelable = eventInitConfig.cancelable;
    var data = eventInitConfig.data;
    var origin = eventInitConfig.origin;
    var lastEventId = eventInitConfig.lastEventId;
    var ports = eventInitConfig.ports;

    this.type = String(type);
    this.timeStamp = Date.now();
    this.target = null;
    this.srcElement = null;
    this.returnValue = true;
    this.isTrusted = false;
    this.eventPhase = 0;
    this.defaultPrevented = false;
    this.currentTarget = null;
    this.cancelable = cancelable ? Boolean(cancelable) : false;
    this.canncelBubble = false;
    this.bubbles = bubbles ? Boolean(bubbles) : false;
    this.origin = origin ? String(origin) : '';
    this.ports = typeof ports === 'undefined' ? null : ports;
    this.data = typeof data === 'undefined' ? null : data;
    this.lastEventId = lastEventId ? String(lastEventId) : '';
  }

  return MessageEvent;
})(_eventPrototype2['default']);

exports['default'] = MessageEvent;
module.exports = exports['default'];
},{"./event-prototype":11}],14:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

var _server = require('./server');

var _server2 = _interopRequireDefault(_server);

var _socketIo = require('./socket-io');

var _socketIo2 = _interopRequireDefault(_socketIo);

var _websocket = require('./websocket');

var _websocket2 = _interopRequireDefault(_websocket);

if (typeof window !== 'undefined') {
  window.MockServer = _server2['default'];
  window.MockWebSocket = _websocket2['default'];
  window.MockSocketIO = _socketIo2['default'];
}

var Server = _server2['default'];
exports.Server = Server;
var WebSocket = _websocket2['default'];
exports.WebSocket = WebSocket;
var SocketIO = _socketIo2['default'];
exports.SocketIO = SocketIO;
},{"./server":16,"./socket-io":17,"./websocket":18}],15:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

var _helpersArrayHelpers = require('./helpers/array-helpers');

/*
* The network bridge is a way for the mock websocket object to 'communicate' with
* all avalible servers. This is a singleton object so it is important that you
* clean up urlMap whenever you are finished.
*/

var NetworkBridge = (function () {
  function NetworkBridge() {
    _classCallCheck(this, NetworkBridge);

    this.urlMap = {};
  }

  /*
  * Attaches a websocket object to the urlMap hash so that it can find the server
  * it is connected to and the server in turn can find it.
  *
  * @param {object} websocket - websocket object to add to the urlMap hash
  * @param {string} url
  */

  _createClass(NetworkBridge, [{
    key: 'attachWebSocket',
    value: function attachWebSocket(websocket, url) {
      var connectionLookup = this.urlMap[url];

      if (connectionLookup && connectionLookup.server && connectionLookup.websockets.indexOf(websocket) === -1) {
        connectionLookup.websockets.push(websocket);
        return connectionLookup.server;
      }
    }

    /*
    * Attaches a websocket to a room
    */
  }, {
    key: 'addMembershipToRoom',
    value: function addMembershipToRoom(websocket, room) {
      var connectionLookup = this.urlMap[websocket.url];

      if (connectionLookup && connectionLookup.server && connectionLookup.websockets.indexOf(websocket) !== -1) {
        if (!connectionLookup.roomMemberships[room]) {
          connectionLookup.roomMemberships[room] = [];
        }

        connectionLookup.roomMemberships[room].push(websocket);
      }
    }

    /*
    * Attaches a server object to the urlMap hash so that it can find a websockets
    * which are connected to it and so that websockets can in turn can find it.
    *
    * @param {object} server - server object to add to the urlMap hash
    * @param {string} url
    */
  }, {
    key: 'attachServer',
    value: function attachServer(server, url) {
      var connectionLookup = this.urlMap[url];

      if (!connectionLookup) {
        this.urlMap[url] = {
          server: server,
          websockets: [],
          roomMemberships: {}
        };

        return server;
      }
    }

    /*
    * Finds the server which is 'running' on the given url.
    *
    * @param {string} url - the url to use to find which server is running on it
    */
  }, {
    key: 'serverLookup',
    value: function serverLookup(url) {
      var connectionLookup = this.urlMap[url];

      if (connectionLookup) {
        return connectionLookup.server;
      }
    }

    /*
    * Finds all websockets which is 'listening' on the given url.
    *
    * @param {string} url - the url to use to find all websockets which are associated with it
    * @param {string} room - if a room is provided, will only return sockets in this room
    */
  }, {
    key: 'websocketsLookup',
    value: function websocketsLookup(url, room) {
      var connectionLookup = this.urlMap[url];

      if (!connectionLookup) {
        return [];
      }

      if (room) {
        var members = connectionLookup.roomMemberships[room];
        return members ? members : [];
      }

      return connectionLookup.websockets;
    }

    /*
    * Removes the entry associated with the url.
    *
    * @param {string} url
    */
  }, {
    key: 'removeServer',
    value: function removeServer(url) {
      delete this.urlMap[url];
    }

    /*
    * Removes the individual websocket from the map of associated websockets.
    *
    * @param {object} websocket - websocket object to remove from the url map
    * @param {string} url
    */
  }, {
    key: 'removeWebSocket',
    value: function removeWebSocket(websocket, url) {
      var connectionLookup = this.urlMap[url];

      if (connectionLookup) {
        connectionLookup.websockets = (0, _helpersArrayHelpers.reject)(connectionLookup.websockets, function (socket) {
          return socket === websocket;
        });
      }
    }

    /*
    * Removes a websocket from a room
    */
  }, {
    key: 'removeMembershipFromRoom',
    value: function removeMembershipFromRoom(websocket, room) {
      var connectionLookup = this.urlMap[websocket.url];
      var memberships = connectionLookup.roomMemberships[room];

      if (connectionLookup && memberships !== null) {
        connectionLookup.roomMemberships[room] = (0, _helpersArrayHelpers.reject)(memberships, function (socket) {
          return socket === websocket;
        });
      }
    }
  }]);

  return NetworkBridge;
})();

exports['default'] = new NetworkBridge();
// Note: this is a singleton
module.exports = exports['default'];
},{"./helpers/array-helpers":7}],16:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

var _get = function get(_x4, _x5, _x6) { var _again = true; _function: while (_again) { var object = _x4, property = _x5, receiver = _x6; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x4 = parent; _x5 = property; _x6 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _urijs = require('urijs');

var _urijs2 = _interopRequireDefault(_urijs);

var _websocket = require('./websocket');

var _websocket2 = _interopRequireDefault(_websocket);

var _eventTarget = require('./event-target');

var _eventTarget2 = _interopRequireDefault(_eventTarget);

var _networkBridge = require('./network-bridge');

var _networkBridge2 = _interopRequireDefault(_networkBridge);

var _helpersCloseCodes = require('./helpers/close-codes');

var _helpersCloseCodes2 = _interopRequireDefault(_helpersCloseCodes);

var _eventFactory = require('./event-factory');

/*
* https://github.com/websockets/ws#server-example
*/

var Server = (function (_EventTarget) {
  _inherits(Server, _EventTarget);

  /*
  * @param {string} url
  */

  function Server(url) {
    _classCallCheck(this, Server);

    _get(Object.getPrototypeOf(Server.prototype), 'constructor', this).call(this);
    this.url = (0, _urijs2['default'])(url).toString();
    var server = _networkBridge2['default'].attachServer(this, this.url);

    if (!server) {
      this.dispatchEvent((0, _eventFactory.createEvent)({ type: 'error' }));
      throw new Error('A mock server is already listening on this url');
    }
  }

  /*
   * Alternative constructor to support namespaces in socket.io
   *
   * http://socket.io/docs/rooms-and-namespaces/#custom-namespaces
   */

  /*
  * This is the main function for the mock server to subscribe to the on events.
  *
  * ie: mockServer.on('connection', function() { console.log('a mock client connected'); });
  *
  * @param {string} type - The event key to subscribe to. Valid keys are: connection, message, and close.
  * @param {function} callback - The callback which should be called when a certain event is fired.
  */

  _createClass(Server, [{
    key: 'on',
    value: function on(type, callback) {
      this.addEventListener(type, callback);
    }

    /*
    * This send function will notify all mock clients via their onmessage callbacks that the server
    * has a message for them.
    *
    * @param {*} data - Any javascript object which will be crafted into a MessageObject.
    */
  }, {
    key: 'send',
    value: function send(data) {
      var options = arguments.length <= 1 || arguments[1] === undefined ? {} : arguments[1];

      this.emit('message', data, options);
    }

    /*
    * Sends a generic message event to all mock clients.
    */
  }, {
    key: 'emit',
    value: function emit(event, data) {
      var _this2 = this;

      var options = arguments.length <= 2 || arguments[2] === undefined ? {} : arguments[2];
      var websockets = options.websockets;

      if (!websockets) {
        websockets = _networkBridge2['default'].websocketsLookup(this.url);
      }

      websockets.forEach(function (socket) {
        socket.dispatchEvent((0, _eventFactory.createMessageEvent)({
          type: event,
          data: data,
          origin: _this2.url,
          target: socket
        }));
      });
    }

    /*
    * Closes the connection and triggers the onclose method of all listening
    * websockets. After that it removes itself from the urlMap so another server
    * could add itself to the url.
    *
    * @param {object} options
    */
  }, {
    key: 'close',
    value: function close() {
      var options = arguments.length <= 0 || arguments[0] === undefined ? {} : arguments[0];
      var code = options.code;
      var reason = options.reason;
      var wasClean = options.wasClean;

      var listeners = _networkBridge2['default'].websocketsLookup(this.url);

      listeners.forEach(function (socket) {
        socket.readyState = _websocket2['default'].CLOSE;
        socket.dispatchEvent((0, _eventFactory.createCloseEvent)({
          type: 'close',
          target: socket,
          code: code || _helpersCloseCodes2['default'].CLOSE_NORMAL,
          reason: reason || '',
          wasClean: wasClean
        }));
      });

      this.dispatchEvent((0, _eventFactory.createCloseEvent)({ type: 'close' }), this);
      _networkBridge2['default'].removeServer(this.url);
    }

    /*
    * Returns an array of websockets which are listening to this server
    */
  }, {
    key: 'clients',
    value: function clients() {
      return _networkBridge2['default'].websocketsLookup(this.url);
    }

    /*
    * Prepares a method to submit an event to members of the room
    *
    * e.g. server.to('my-room').emit('hi!');
    */
  }, {
    key: 'to',
    value: function to(room) {
      var _this = this;
      var websockets = _networkBridge2['default'].websocketsLookup(this.url, room);
      return {
        emit: function emit(event, data) {
          _this.emit(event, data, { websockets: websockets });
        }
      };
    }
  }]);

  return Server;
})(_eventTarget2['default']);

Server.of = function of(url) {
  return new Server(url);
};

exports['default'] = Server;
module.exports = exports['default'];
},{"./event-factory":5,"./event-target":6,"./helpers/close-codes":8,"./network-bridge":15,"./websocket":18,"urijs":3}],17:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

var _get = function get(_x3, _x4, _x5) { var _again = true; _function: while (_again) { var object = _x3, property = _x4, receiver = _x5; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x3 = parent; _x4 = property; _x5 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _urijs = require('urijs');

var _urijs2 = _interopRequireDefault(_urijs);

var _helpersDelay = require('./helpers/delay');

var _helpersDelay2 = _interopRequireDefault(_helpersDelay);

var _eventTarget = require('./event-target');

var _eventTarget2 = _interopRequireDefault(_eventTarget);

var _networkBridge = require('./network-bridge');

var _networkBridge2 = _interopRequireDefault(_networkBridge);

var _helpersCloseCodes = require('./helpers/close-codes');

var _helpersCloseCodes2 = _interopRequireDefault(_helpersCloseCodes);

var _eventFactory = require('./event-factory');

/*
* The socket-io class is designed to mimick the real API as closely as possible.
*
* http://socket.io/docs/
*/

var SocketIO = (function (_EventTarget) {
  _inherits(SocketIO, _EventTarget);

  /*
  * @param {string} url
  */

  function SocketIO() {
    var _this = this;

    var url = arguments.length <= 0 || arguments[0] === undefined ? 'socket.io' : arguments[0];
    var protocol = arguments.length <= 1 || arguments[1] === undefined ? '' : arguments[1];

    _classCallCheck(this, SocketIO);

    _get(Object.getPrototypeOf(SocketIO.prototype), 'constructor', this).call(this);

    this.binaryType = 'blob';
    this.url = (0, _urijs2['default'])(url).toString();
    this.readyState = SocketIO.CONNECTING;
    this.protocol = '';

    if (typeof protocol === 'string') {
      this.protocol = protocol;
    } else if (Array.isArray(protocol) && protocol.length > 0) {
      this.protocol = protocol[0];
    }

    var server = _networkBridge2['default'].attachWebSocket(this, this.url);

    /*
    * Delay triggering the connection events so they can be defined in time.
    */
    (0, _helpersDelay2['default'])(function delayCallback() {
      if (server) {
        this.readyState = SocketIO.OPEN;
        server.dispatchEvent((0, _eventFactory.createEvent)({ type: 'connection' }), server, this);
        server.dispatchEvent((0, _eventFactory.createEvent)({ type: 'connect' }), server, this); // alias
        this.dispatchEvent((0, _eventFactory.createEvent)({ type: 'connect', target: this }));
      } else {
        this.readyState = SocketIO.CLOSED;
        this.dispatchEvent((0, _eventFactory.createEvent)({ type: 'error', target: this }));
        this.dispatchEvent((0, _eventFactory.createCloseEvent)({
          type: 'close',
          target: this,
          code: _helpersCloseCodes2['default'].CLOSE_NORMAL
        }));

        console.error('Socket.io connection to \'' + this.url + '\' failed');
      }
    }, this);

    /**
      Add an aliased event listener for close / disconnect
     */
    this.addEventListener('close', function (event) {
      _this.dispatchEvent((0, _eventFactory.createCloseEvent)({
        type: 'disconnect',
        target: event.target,
        code: event.code
      }));
    });
  }

  /*
  * Closes the SocketIO connection or connection attempt, if any.
  * If the connection is already CLOSED, this method does nothing.
  */

  _createClass(SocketIO, [{
    key: 'close',
    value: function close() {
      if (this.readyState !== SocketIO.OPEN) {
        return undefined;
      }

      var server = _networkBridge2['default'].serverLookup(this.url);
      _networkBridge2['default'].removeWebSocket(this, this.url);

      this.readyState = SocketIO.CLOSED;
      this.dispatchEvent((0, _eventFactory.createCloseEvent)({
        type: 'close',
        target: this,
        code: _helpersCloseCodes2['default'].CLOSE_NORMAL
      }));

      if (server) {
        server.dispatchEvent((0, _eventFactory.createCloseEvent)({
          type: 'disconnect',
          target: this,
          code: _helpersCloseCodes2['default'].CLOSE_NORMAL
        }), server);
      }
    }

    /*
    * Alias for Socket#close
    *
    * https://github.com/socketio/socket.io-client/blob/master/lib/socket.js#L383
    */
  }, {
    key: 'disconnect',
    value: function disconnect() {
      this.close();
    }

    /*
    * Submits an event to the server with a payload
    */
  }, {
    key: 'emit',
    value: function emit(event, data) {
      if (this.readyState !== SocketIO.OPEN) {
        throw new Error('SocketIO is already in CLOSING or CLOSED state');
      }

      var messageEvent = (0, _eventFactory.createMessageEvent)({
        type: event,
        origin: this.url,
        data: data
      });

      var server = _networkBridge2['default'].serverLookup(this.url);

      if (server) {
        server.dispatchEvent(messageEvent, data);
      }
    }

    /*
    * Submits a 'message' event to the server.
    *
    * Should behave exactly like WebSocket#send
    *
    * https://github.com/socketio/socket.io-client/blob/master/lib/socket.js#L113
    */
  }, {
    key: 'send',
    value: function send(data) {
      this.emit('message', data);
    }

    /*
    * For registering events to be received from the server
    */
  }, {
    key: 'on',
    value: function on(type, callback) {
      this.addEventListener(type, callback);
    }

    /*
     * Join a room on a server
     *
     * http://socket.io/docs/rooms-and-namespaces/#joining-and-leaving
     */
  }, {
    key: 'join',
    value: function join(room) {
      _networkBridge2['default'].addMembershipToRoom(this, room);
    }

    /*
     * Get the websocket to leave the room
     *
     * http://socket.io/docs/rooms-and-namespaces/#joining-and-leaving
     */
  }, {
    key: 'leave',
    value: function leave(room) {
      _networkBridge2['default'].removeMembershipFromRoom(this, room);
    }

    /*
     * Invokes all listener functions that are listening to the given event.type property. Each
     * listener will be passed the event as the first argument.
     *
     * @param {object} event - event object which will be passed to all listeners of the event.type property
     */
  }, {
    key: 'dispatchEvent',
    value: function dispatchEvent(event) {
      var _this2 = this;

      for (var _len = arguments.length, customArguments = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        customArguments[_key - 1] = arguments[_key];
      }

      var eventName = event.type;
      var listeners = this.listeners[eventName];

      if (!Array.isArray(listeners)) {
        return false;
      }

      listeners.forEach(function (listener) {
        if (customArguments.length > 0) {
          listener.apply(_this2, customArguments);
        } else {
          // Regular WebSockets expect a MessageEvent but Socketio.io just wants raw data
          //  payload instanceof MessageEvent works, but you can't isntance of NodeEvent
          //  for now we detect if the output has data defined on it
          listener.call(_this2, event.data ? event.data : event);
        }
      });
    }
  }]);

  return SocketIO;
})(_eventTarget2['default']);

SocketIO.CONNECTING = 0;
SocketIO.OPEN = 1;
SocketIO.CLOSING = 2;
SocketIO.CLOSED = 3;

/*
* Static constructor methods for the IO Socket
*/
var IO = function ioConstructor(url) {
  return new SocketIO(url);
};

/*
* Alias the raw IO() constructor
*/
IO.connect = function ioConnect(url) {
  /* eslint-disable new-cap */
  return IO(url);
  /* eslint-enable new-cap */
};

exports['default'] = IO;
module.exports = exports['default'];
},{"./event-factory":5,"./event-target":6,"./helpers/close-codes":8,"./helpers/delay":10,"./network-bridge":15,"urijs":3}],18:[function(require,module,exports){
'use strict';

Object.defineProperty(exports, '__esModule', {
  value: true
});

var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

var _get = function get(_x2, _x3, _x4) { var _again = true; _function: while (_again) { var object = _x2, property = _x3, receiver = _x4; _again = false; if (object === null) object = Function.prototype; var desc = Object.getOwnPropertyDescriptor(object, property); if (desc === undefined) { var parent = Object.getPrototypeOf(object); if (parent === null) { return undefined; } else { _x2 = parent; _x3 = property; _x4 = receiver; _again = true; desc = parent = undefined; continue _function; } } else if ('value' in desc) { return desc.value; } else { var getter = desc.get; if (getter === undefined) { return undefined; } return getter.call(receiver); } } };

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

function _inherits(subClass, superClass) { if (typeof superClass !== 'function' && superClass !== null) { throw new TypeError('Super expression must either be null or a function, not ' + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _urijs = require('urijs');

var _urijs2 = _interopRequireDefault(_urijs);

var _helpersDelay = require('./helpers/delay');

var _helpersDelay2 = _interopRequireDefault(_helpersDelay);

var _eventTarget = require('./event-target');

var _eventTarget2 = _interopRequireDefault(_eventTarget);

var _networkBridge = require('./network-bridge');

var _networkBridge2 = _interopRequireDefault(_networkBridge);

var _helpersCloseCodes = require('./helpers/close-codes');

var _helpersCloseCodes2 = _interopRequireDefault(_helpersCloseCodes);

var _eventFactory = require('./event-factory');

/*
* The main websocket class which is designed to mimick the native WebSocket class as close
* as possible.
*
* https://developer.mozilla.org/en-US/docs/Web/API/WebSocket
*/

var WebSocket = (function (_EventTarget) {
  _inherits(WebSocket, _EventTarget);

  /*
  * @param {string} url
  */

  function WebSocket(url) {
    var protocol = arguments.length <= 1 || arguments[1] === undefined ? '' : arguments[1];

    _classCallCheck(this, WebSocket);

    _get(Object.getPrototypeOf(WebSocket.prototype), 'constructor', this).call(this);

    if (!url) {
      throw new TypeError('Failed to construct \'WebSocket\': 1 argument required, but only 0 present.');
    }

    this.binaryType = 'blob';
    this.url = (0, _urijs2['default'])(url).toString();
    this.readyState = WebSocket.CONNECTING;
    this.protocol = '';

    if (typeof protocol === 'string') {
      this.protocol = protocol;
    } else if (Array.isArray(protocol) && protocol.length > 0) {
      this.protocol = protocol[0];
    }

    /*
    * In order to capture the callback function we need to define custom setters.
    * To illustrate:
    *   mySocket.onopen = function() { alert(true) };
    *
    * The only way to capture that function and hold onto it for later is with the
    * below code:
    */
    Object.defineProperties(this, {
      onopen: {
        configurable: true,
        enumerable: true,
        get: function get() {
          return this.listeners.open;
        },
        set: function set(listener) {
          this.addEventListener('open', listener);
        }
      },
      onmessage: {
        configurable: true,
        enumerable: true,
        get: function get() {
          return this.listeners.message;
        },
        set: function set(listener) {
          this.addEventListener('message', listener);
        }
      },
      onclose: {
        configurable: true,
        enumerable: true,
        get: function get() {
          return this.listeners.close;
        },
        set: function set(listener) {
          this.addEventListener('close', listener);
        }
      },
      onerror: {
        configurable: true,
        enumerable: true,
        get: function get() {
          return this.listeners.error;
        },
        set: function set(listener) {
          this.addEventListener('error', listener);
        }
      }
    });

    var server = _networkBridge2['default'].attachWebSocket(this, this.url);

    /*
    * This delay is needed so that we dont trigger an event before the callbacks have been
    * setup. For example:
    *
    * var socket = new WebSocket('ws://localhost');
    *
    * // If we dont have the delay then the event would be triggered right here and this is
    * // before the onopen had a chance to register itself.
    *
    * socket.onopen = () => { // this would never be called };
    *
    * // and with the delay the event gets triggered here after all of the callbacks have been
    * // registered :-)
    */
    (0, _helpersDelay2['default'])(function delayCallback() {
      if (server) {
        this.readyState = WebSocket.OPEN;
        server.dispatchEvent((0, _eventFactory.createEvent)({ type: 'connection' }), server, this);
        this.dispatchEvent((0, _eventFactory.createEvent)({ type: 'open', target: this }));
      } else {
        this.readyState = WebSocket.CLOSED;
        this.dispatchEvent((0, _eventFactory.createEvent)({ type: 'error', target: this }));
        this.dispatchEvent((0, _eventFactory.createCloseEvent)({ type: 'close', target: this, code: _helpersCloseCodes2['default'].CLOSE_NORMAL }));

        console.error('WebSocket connection to \'' + this.url + '\' failed');
      }
    }, this);
  }

  /*
  * Transmits data to the server over the WebSocket connection.
  *
  * https://developer.mozilla.org/en-US/docs/Web/API/WebSocket#send()
  */

  _createClass(WebSocket, [{
    key: 'send',
    value: function send(data) {
      if (this.readyState === WebSocket.CLOSING || this.readyState === WebSocket.CLOSED) {
        throw new Error('WebSocket is already in CLOSING or CLOSED state');
      }

      var messageEvent = (0, _eventFactory.createMessageEvent)({
        type: 'message',
        origin: this.url,
        data: data
      });

      var server = _networkBridge2['default'].serverLookup(this.url);

      if (server) {
        server.dispatchEvent(messageEvent, data);
      }
    }

    /*
    * Closes the WebSocket connection or connection attempt, if any.
    * If the connection is already CLOSED, this method does nothing.
    *
    * https://developer.mozilla.org/en-US/docs/Web/API/WebSocket#close()
    */
  }, {
    key: 'close',
    value: function close() {
      if (this.readyState !== WebSocket.OPEN) {
        return undefined;
      }

      var server = _networkBridge2['default'].serverLookup(this.url);
      var closeEvent = (0, _eventFactory.createCloseEvent)({
        type: 'close',
        target: this,
        code: _helpersCloseCodes2['default'].CLOSE_NORMAL
      });

      _networkBridge2['default'].removeWebSocket(this, this.url);

      this.readyState = WebSocket.CLOSED;
      this.dispatchEvent(closeEvent);

      if (server) {
        server.dispatchEvent(closeEvent, server);
      }
    }
  }]);

  return WebSocket;
})(_eventTarget2['default']);

WebSocket.CONNECTING = 0;
WebSocket.OPEN = 1;
WebSocket.CLOSING = 2;
WebSocket.CLOSED = 3;

exports['default'] = WebSocket;
module.exports = exports['default'];
},{"./event-factory":5,"./event-target":6,"./helpers/close-codes":8,"./helpers/delay":10,"./network-bridge":15,"urijs":3}]},{},[14])
//# sourceMappingURL=data:application/json;charset:utf-8;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIi4uLy4uL25vZGVfbW9kdWxlcy9icm93c2VyLXBhY2svX3ByZWx1ZGUuanMiLCIuLi8uLi9ub2RlX21vZHVsZXMvdXJpanMvc3JjL0lQdjYuanMiLCIuLi8uLi9ub2RlX21vZHVsZXMvdXJpanMvc3JjL1NlY29uZExldmVsRG9tYWlucy5qcyIsIi4uLy4uL25vZGVfbW9kdWxlcy91cmlqcy9zcmMvVVJJLmpzIiwiLi4vLi4vbm9kZV9tb2R1bGVzL3VyaWpzL3NyYy9wdW55Y29kZS5qcyIsImV2ZW50LWZhY3RvcnkuanMiLCJldmVudC10YXJnZXQuanMiLCJoZWxwZXJzL2FycmF5LWhlbHBlcnMuanMiLCJoZWxwZXJzL2Nsb3NlLWNvZGVzLmpzIiwiaGVscGVycy9jbG9zZS1ldmVudC5qcyIsImhlbHBlcnMvZGVsYXkuanMiLCJoZWxwZXJzL2V2ZW50LXByb3RvdHlwZS5qcyIsImhlbHBlcnMvZXZlbnQuanMiLCJoZWxwZXJzL21lc3NhZ2UtZXZlbnQuanMiLCJtYWluLmpzIiwibmV0d29yay1icmlkZ2UuanMiLCJzZXJ2ZXIuanMiLCJzb2NrZXQtaW8uanMiLCJ3ZWJzb2NrZXQuanMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUE7QUNBQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDNUxBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDalBBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7OztBQ2puRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7OztBQzVmQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDckdBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUN4R0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUM1QkE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUNuQkE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDL0RBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUNwQkE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDN0NBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQ3pEQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDakVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDL0JBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUM3S0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDN0xBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FDclJBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBIiwiZmlsZSI6ImdlbmVyYXRlZC5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzQ29udGVudCI6WyIoZnVuY3Rpb24gZSh0LG4scil7ZnVuY3Rpb24gcyhvLHUpe2lmKCFuW29dKXtpZighdFtvXSl7dmFyIGE9dHlwZW9mIHJlcXVpcmU9PVwiZnVuY3Rpb25cIiYmcmVxdWlyZTtpZighdSYmYSlyZXR1cm4gYShvLCEwKTtpZihpKXJldHVybiBpKG8sITApO3ZhciBmPW5ldyBFcnJvcihcIkNhbm5vdCBmaW5kIG1vZHVsZSAnXCIrbytcIidcIik7dGhyb3cgZi5jb2RlPVwiTU9EVUxFX05PVF9GT1VORFwiLGZ9dmFyIGw9bltvXT17ZXhwb3J0czp7fX07dFtvXVswXS5jYWxsKGwuZXhwb3J0cyxmdW5jdGlvbihlKXt2YXIgbj10W29dWzFdW2VdO3JldHVybiBzKG4/bjplKX0sbCxsLmV4cG9ydHMsZSx0LG4scil9cmV0dXJuIG5bb10uZXhwb3J0c312YXIgaT10eXBlb2YgcmVxdWlyZT09XCJmdW5jdGlvblwiJiZyZXF1aXJlO2Zvcih2YXIgbz0wO288ci5sZW5ndGg7bysrKXMocltvXSk7cmV0dXJuIHN9KSIsIi8qIVxuICogVVJJLmpzIC0gTXV0YXRpbmcgVVJMc1xuICogSVB2NiBTdXBwb3J0XG4gKlxuICogVmVyc2lvbjogMS4xNy4wXG4gKlxuICogQXV0aG9yOiBSb2RuZXkgUmVobVxuICogV2ViOiBodHRwOi8vbWVkaWFsaXplLmdpdGh1Yi5pby9VUkkuanMvXG4gKlxuICogTGljZW5zZWQgdW5kZXJcbiAqICAgTUlUIExpY2Vuc2UgaHR0cDovL3d3dy5vcGVuc291cmNlLm9yZy9saWNlbnNlcy9taXQtbGljZW5zZVxuICogICBHUEwgdjMgaHR0cDovL29wZW5zb3VyY2Uub3JnL2xpY2Vuc2VzL0dQTC0zLjBcbiAqXG4gKi9cblxuKGZ1bmN0aW9uIChyb290LCBmYWN0b3J5KSB7XG4gICd1c2Ugc3RyaWN0JztcbiAgLy8gaHR0cHM6Ly9naXRodWIuY29tL3VtZGpzL3VtZC9ibG9iL21hc3Rlci9yZXR1cm5FeHBvcnRzLmpzXG4gIGlmICh0eXBlb2YgZXhwb3J0cyA9PT0gJ29iamVjdCcpIHtcbiAgICAvLyBOb2RlXG4gICAgbW9kdWxlLmV4cG9ydHMgPSBmYWN0b3J5KCk7XG4gIH0gZWxzZSBpZiAodHlwZW9mIGRlZmluZSA9PT0gJ2Z1bmN0aW9uJyAmJiBkZWZpbmUuYW1kKSB7XG4gICAgLy8gQU1ELiBSZWdpc3RlciBhcyBhbiBhbm9ueW1vdXMgbW9kdWxlLlxuICAgIGRlZmluZShmYWN0b3J5KTtcbiAgfSBlbHNlIHtcbiAgICAvLyBCcm93c2VyIGdsb2JhbHMgKHJvb3QgaXMgd2luZG93KVxuICAgIHJvb3QuSVB2NiA9IGZhY3Rvcnkocm9vdCk7XG4gIH1cbn0odGhpcywgZnVuY3Rpb24gKHJvb3QpIHtcbiAgJ3VzZSBzdHJpY3QnO1xuXG4gIC8qXG4gIHZhciBfaW4gPSBcImZlODA6MDAwMDowMDAwOjAwMDA6MDIwNDo2MWZmOmZlOWQ6ZjE1NlwiO1xuICB2YXIgX291dCA9IElQdjYuYmVzdChfaW4pO1xuICB2YXIgX2V4cGVjdGVkID0gXCJmZTgwOjoyMDQ6NjFmZjpmZTlkOmYxNTZcIjtcblxuICBjb25zb2xlLmxvZyhfaW4sIF9vdXQsIF9leHBlY3RlZCwgX291dCA9PT0gX2V4cGVjdGVkKTtcbiAgKi9cblxuICAvLyBzYXZlIGN1cnJlbnQgSVB2NiB2YXJpYWJsZSwgaWYgYW55XG4gIHZhciBfSVB2NiA9IHJvb3QgJiYgcm9vdC5JUHY2O1xuXG4gIGZ1bmN0aW9uIGJlc3RQcmVzZW50YXRpb24oYWRkcmVzcykge1xuICAgIC8vIGJhc2VkIG9uOlxuICAgIC8vIEphdmFzY3JpcHQgdG8gdGVzdCBhbiBJUHY2IGFkZHJlc3MgZm9yIHByb3BlciBmb3JtYXQsIGFuZCB0b1xuICAgIC8vIHByZXNlbnQgdGhlIFwiYmVzdCB0ZXh0IHJlcHJlc2VudGF0aW9uXCIgYWNjb3JkaW5nIHRvIElFVEYgRHJhZnQgUkZDIGF0XG4gICAgLy8gaHR0cDovL3Rvb2xzLmlldGYub3JnL2h0bWwvZHJhZnQtaWV0Zi02bWFuLXRleHQtYWRkci1yZXByZXNlbnRhdGlvbi0wNFxuICAgIC8vIDggRmViIDIwMTAgUmljaCBCcm93biwgRGFydHdhcmUsIExMQ1xuICAgIC8vIFBsZWFzZSBmZWVsIGZyZWUgdG8gdXNlIHRoaXMgY29kZSBhcyBsb25nIGFzIHlvdSBwcm92aWRlIGEgbGluayB0b1xuICAgIC8vIGh0dHA6Ly93d3cuaW50ZXJtYXBwZXIuY29tXG4gICAgLy8gaHR0cDovL2ludGVybWFwcGVyLmNvbS9zdXBwb3J0L3Rvb2xzL0lQVjYtVmFsaWRhdG9yLmFzcHhcbiAgICAvLyBodHRwOi8vZG93bmxvYWQuZGFydHdhcmUuY29tL3RoaXJkcGFydHkvaXB2NnZhbGlkYXRvci5qc1xuXG4gICAgdmFyIF9hZGRyZXNzID0gYWRkcmVzcy50b0xvd2VyQ2FzZSgpO1xuICAgIHZhciBzZWdtZW50cyA9IF9hZGRyZXNzLnNwbGl0KCc6Jyk7XG4gICAgdmFyIGxlbmd0aCA9IHNlZ21lbnRzLmxlbmd0aDtcbiAgICB2YXIgdG90YWwgPSA4O1xuXG4gICAgLy8gdHJpbSBjb2xvbnMgKDo6IG9yIDo6YTpiOmPigKYgb3Ig4oCmYTpiOmM6OilcbiAgICBpZiAoc2VnbWVudHNbMF0gPT09ICcnICYmIHNlZ21lbnRzWzFdID09PSAnJyAmJiBzZWdtZW50c1syXSA9PT0gJycpIHtcbiAgICAgIC8vIG11c3QgaGF2ZSBiZWVuIDo6XG4gICAgICAvLyByZW1vdmUgZmlyc3QgdHdvIGl0ZW1zXG4gICAgICBzZWdtZW50cy5zaGlmdCgpO1xuICAgICAgc2VnbWVudHMuc2hpZnQoKTtcbiAgICB9IGVsc2UgaWYgKHNlZ21lbnRzWzBdID09PSAnJyAmJiBzZWdtZW50c1sxXSA9PT0gJycpIHtcbiAgICAgIC8vIG11c3QgaGF2ZSBiZWVuIDo6eHh4eFxuICAgICAgLy8gcmVtb3ZlIHRoZSBmaXJzdCBpdGVtXG4gICAgICBzZWdtZW50cy5zaGlmdCgpO1xuICAgIH0gZWxzZSBpZiAoc2VnbWVudHNbbGVuZ3RoIC0gMV0gPT09ICcnICYmIHNlZ21lbnRzW2xlbmd0aCAtIDJdID09PSAnJykge1xuICAgICAgLy8gbXVzdCBoYXZlIGJlZW4geHh4eDo6XG4gICAgICBzZWdtZW50cy5wb3AoKTtcbiAgICB9XG5cbiAgICBsZW5ndGggPSBzZWdtZW50cy5sZW5ndGg7XG5cbiAgICAvLyBhZGp1c3QgdG90YWwgc2VnbWVudHMgZm9yIElQdjQgdHJhaWxlclxuICAgIGlmIChzZWdtZW50c1tsZW5ndGggLSAxXS5pbmRleE9mKCcuJykgIT09IC0xKSB7XG4gICAgICAvLyBmb3VuZCBhIFwiLlwiIHdoaWNoIG1lYW5zIElQdjRcbiAgICAgIHRvdGFsID0gNztcbiAgICB9XG5cbiAgICAvLyBmaWxsIGVtcHR5IHNlZ21lbnRzIHRoZW0gd2l0aCBcIjAwMDBcIlxuICAgIHZhciBwb3M7XG4gICAgZm9yIChwb3MgPSAwOyBwb3MgPCBsZW5ndGg7IHBvcysrKSB7XG4gICAgICBpZiAoc2VnbWVudHNbcG9zXSA9PT0gJycpIHtcbiAgICAgICAgYnJlYWs7XG4gICAgICB9XG4gICAgfVxuXG4gICAgaWYgKHBvcyA8IHRvdGFsKSB7XG4gICAgICBzZWdtZW50cy5zcGxpY2UocG9zLCAxLCAnMDAwMCcpO1xuICAgICAgd2hpbGUgKHNlZ21lbnRzLmxlbmd0aCA8IHRvdGFsKSB7XG4gICAgICAgIHNlZ21lbnRzLnNwbGljZShwb3MsIDAsICcwMDAwJyk7XG4gICAgICB9XG5cbiAgICAgIGxlbmd0aCA9IHNlZ21lbnRzLmxlbmd0aDtcbiAgICB9XG5cbiAgICAvLyBzdHJpcCBsZWFkaW5nIHplcm9zXG4gICAgdmFyIF9zZWdtZW50cztcbiAgICBmb3IgKHZhciBpID0gMDsgaSA8IHRvdGFsOyBpKyspIHtcbiAgICAgIF9zZWdtZW50cyA9IHNlZ21lbnRzW2ldLnNwbGl0KCcnKTtcbiAgICAgIGZvciAodmFyIGogPSAwOyBqIDwgMyA7IGorKykge1xuICAgICAgICBpZiAoX3NlZ21lbnRzWzBdID09PSAnMCcgJiYgX3NlZ21lbnRzLmxlbmd0aCA+IDEpIHtcbiAgICAgICAgICBfc2VnbWVudHMuc3BsaWNlKDAsMSk7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICAgIH1cblxuICAgICAgc2VnbWVudHNbaV0gPSBfc2VnbWVudHMuam9pbignJyk7XG4gICAgfVxuXG4gICAgLy8gZmluZCBsb25nZXN0IHNlcXVlbmNlIG9mIHplcm9lcyBhbmQgY29hbGVzY2UgdGhlbSBpbnRvIG9uZSBzZWdtZW50XG4gICAgdmFyIGJlc3QgPSAtMTtcbiAgICB2YXIgX2Jlc3QgPSAwO1xuICAgIHZhciBfY3VycmVudCA9IDA7XG4gICAgdmFyIGN1cnJlbnQgPSAtMTtcbiAgICB2YXIgaW56ZXJvZXMgPSBmYWxzZTtcbiAgICAvLyBpOyBhbHJlYWR5IGRlY2xhcmVkXG5cbiAgICBmb3IgKGkgPSAwOyBpIDwgdG90YWw7IGkrKykge1xuICAgICAgaWYgKGluemVyb2VzKSB7XG4gICAgICAgIGlmIChzZWdtZW50c1tpXSA9PT0gJzAnKSB7XG4gICAgICAgICAgX2N1cnJlbnQgKz0gMTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBpbnplcm9lcyA9IGZhbHNlO1xuICAgICAgICAgIGlmIChfY3VycmVudCA+IF9iZXN0KSB7XG4gICAgICAgICAgICBiZXN0ID0gY3VycmVudDtcbiAgICAgICAgICAgIF9iZXN0ID0gX2N1cnJlbnQ7XG4gICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBpZiAoc2VnbWVudHNbaV0gPT09ICcwJykge1xuICAgICAgICAgIGluemVyb2VzID0gdHJ1ZTtcbiAgICAgICAgICBjdXJyZW50ID0gaTtcbiAgICAgICAgICBfY3VycmVudCA9IDE7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG5cbiAgICBpZiAoX2N1cnJlbnQgPiBfYmVzdCkge1xuICAgICAgYmVzdCA9IGN1cnJlbnQ7XG4gICAgICBfYmVzdCA9IF9jdXJyZW50O1xuICAgIH1cblxuICAgIGlmIChfYmVzdCA+IDEpIHtcbiAgICAgIHNlZ21lbnRzLnNwbGljZShiZXN0LCBfYmVzdCwgJycpO1xuICAgIH1cblxuICAgIGxlbmd0aCA9IHNlZ21lbnRzLmxlbmd0aDtcblxuICAgIC8vIGFzc2VtYmxlIHJlbWFpbmluZyBzZWdtZW50c1xuICAgIHZhciByZXN1bHQgPSAnJztcbiAgICBpZiAoc2VnbWVudHNbMF0gPT09ICcnKSAge1xuICAgICAgcmVzdWx0ID0gJzonO1xuICAgIH1cblxuICAgIGZvciAoaSA9IDA7IGkgPCBsZW5ndGg7IGkrKykge1xuICAgICAgcmVzdWx0ICs9IHNlZ21lbnRzW2ldO1xuICAgICAgaWYgKGkgPT09IGxlbmd0aCAtIDEpIHtcbiAgICAgICAgYnJlYWs7XG4gICAgICB9XG5cbiAgICAgIHJlc3VsdCArPSAnOic7XG4gICAgfVxuXG4gICAgaWYgKHNlZ21lbnRzW2xlbmd0aCAtIDFdID09PSAnJykge1xuICAgICAgcmVzdWx0ICs9ICc6JztcbiAgICB9XG5cbiAgICByZXR1cm4gcmVzdWx0O1xuICB9XG5cbiAgZnVuY3Rpb24gbm9Db25mbGljdCgpIHtcbiAgICAvKmpzaGludCB2YWxpZHRoaXM6IHRydWUgKi9cbiAgICBpZiAocm9vdC5JUHY2ID09PSB0aGlzKSB7XG4gICAgICByb290LklQdjYgPSBfSVB2NjtcbiAgICB9XG4gIFxuICAgIHJldHVybiB0aGlzO1xuICB9XG5cbiAgcmV0dXJuIHtcbiAgICBiZXN0OiBiZXN0UHJlc2VudGF0aW9uLFxuICAgIG5vQ29uZmxpY3Q6IG5vQ29uZmxpY3RcbiAgfTtcbn0pKTtcbiIsIi8qIVxuICogVVJJLmpzIC0gTXV0YXRpbmcgVVJMc1xuICogU2Vjb25kIExldmVsIERvbWFpbiAoU0xEKSBTdXBwb3J0XG4gKlxuICogVmVyc2lvbjogMS4xNy4wXG4gKlxuICogQXV0aG9yOiBSb2RuZXkgUmVobVxuICogV2ViOiBodHRwOi8vbWVkaWFsaXplLmdpdGh1Yi5pby9VUkkuanMvXG4gKlxuICogTGljZW5zZWQgdW5kZXJcbiAqICAgTUlUIExpY2Vuc2UgaHR0cDovL3d3dy5vcGVuc291cmNlLm9yZy9saWNlbnNlcy9taXQtbGljZW5zZVxuICogICBHUEwgdjMgaHR0cDovL29wZW5zb3VyY2Uub3JnL2xpY2Vuc2VzL0dQTC0zLjBcbiAqXG4gKi9cblxuKGZ1bmN0aW9uIChyb290LCBmYWN0b3J5KSB7XG4gICd1c2Ugc3RyaWN0JztcbiAgLy8gaHR0cHM6Ly9naXRodWIuY29tL3VtZGpzL3VtZC9ibG9iL21hc3Rlci9yZXR1cm5FeHBvcnRzLmpzXG4gIGlmICh0eXBlb2YgZXhwb3J0cyA9PT0gJ29iamVjdCcpIHtcbiAgICAvLyBOb2RlXG4gICAgbW9kdWxlLmV4cG9ydHMgPSBmYWN0b3J5KCk7XG4gIH0gZWxzZSBpZiAodHlwZW9mIGRlZmluZSA9PT0gJ2Z1bmN0aW9uJyAmJiBkZWZpbmUuYW1kKSB7XG4gICAgLy8gQU1ELiBSZWdpc3RlciBhcyBhbiBhbm9ueW1vdXMgbW9kdWxlLlxuICAgIGRlZmluZShmYWN0b3J5KTtcbiAgfSBlbHNlIHtcbiAgICAvLyBCcm93c2VyIGdsb2JhbHMgKHJvb3QgaXMgd2luZG93KVxuICAgIHJvb3QuU2Vjb25kTGV2ZWxEb21haW5zID0gZmFjdG9yeShyb290KTtcbiAgfVxufSh0aGlzLCBmdW5jdGlvbiAocm9vdCkge1xuICAndXNlIHN0cmljdCc7XG5cbiAgLy8gc2F2ZSBjdXJyZW50IFNlY29uZExldmVsRG9tYWlucyB2YXJpYWJsZSwgaWYgYW55XG4gIHZhciBfU2Vjb25kTGV2ZWxEb21haW5zID0gcm9vdCAmJiByb290LlNlY29uZExldmVsRG9tYWlucztcblxuICB2YXIgU0xEID0ge1xuICAgIC8vIGxpc3Qgb2Yga25vd24gU2Vjb25kIExldmVsIERvbWFpbnNcbiAgICAvLyBjb252ZXJ0ZWQgbGlzdCBvZiBTTERzIGZyb20gaHR0cHM6Ly9naXRodWIuY29tL2dhdmluZ21pbGxlci9zZWNvbmQtbGV2ZWwtZG9tYWluc1xuICAgIC8vIC0tLS1cbiAgICAvLyBwdWJsaWNzdWZmaXgub3JnIGlzIG1vcmUgY3VycmVudCBhbmQgYWN0dWFsbHkgdXNlZCBieSBhIGNvdXBsZSBvZiBicm93c2VycyBpbnRlcm5hbGx5LlxuICAgIC8vIGRvd25zaWRlIGlzIGl0IGFsc28gY29udGFpbnMgZG9tYWlucyBsaWtlIFwiZHluZG5zLm9yZ1wiIC0gd2hpY2ggaXMgZmluZSBmb3IgdGhlIHNlY3VyaXR5XG4gICAgLy8gaXNzdWVzIGJyb3dzZXIgaGF2ZSB0byBkZWFsIHdpdGggKFNPUCBmb3IgY29va2llcywgZXRjKSAtIGJ1dCBpcyB3YXkgb3ZlcmJvYXJkIGZvciBVUkkuanNcbiAgICAvLyAtLS0tXG4gICAgbGlzdDoge1xuICAgICAgJ2FjJzonIGNvbSBnb3YgbWlsIG5ldCBvcmcgJyxcbiAgICAgICdhZSc6JyBhYyBjbyBnb3YgbWlsIG5hbWUgbmV0IG9yZyBwcm8gc2NoICcsXG4gICAgICAnYWYnOicgY29tIGVkdSBnb3YgbmV0IG9yZyAnLFxuICAgICAgJ2FsJzonIGNvbSBlZHUgZ292IG1pbCBuZXQgb3JnICcsXG4gICAgICAnYW8nOicgY28gZWQgZ3YgaXQgb2cgcGIgJyxcbiAgICAgICdhcic6JyBjb20gZWR1IGdvYiBnb3YgaW50IG1pbCBuZXQgb3JnIHR1ciAnLFxuICAgICAgJ2F0JzonIGFjIGNvIGd2IG9yICcsXG4gICAgICAnYXUnOicgYXNuIGNvbSBjc2lybyBlZHUgZ292IGlkIG5ldCBvcmcgJyxcbiAgICAgICdiYSc6JyBjbyBjb20gZWR1IGdvdiBtaWwgbmV0IG9yZyBycyB1bmJpIHVubW8gdW5zYSB1bnR6IHVuemUgJyxcbiAgICAgICdiYic6JyBiaXogY28gY29tIGVkdSBnb3YgaW5mbyBuZXQgb3JnIHN0b3JlIHR2ICcsXG4gICAgICAnYmgnOicgYml6IGNjIGNvbSBlZHUgZ292IGluZm8gbmV0IG9yZyAnLFxuICAgICAgJ2JuJzonIGNvbSBlZHUgZ292IG5ldCBvcmcgJyxcbiAgICAgICdibyc6JyBjb20gZWR1IGdvYiBnb3YgaW50IG1pbCBuZXQgb3JnIHR2ICcsXG4gICAgICAnYnInOicgYWRtIGFkdiBhZ3IgYW0gYXJxIGFydCBhdG8gYiBiaW8gYmxvZyBibWQgY2ltIGNuZyBjbnQgY29tIGNvb3AgZWNuIGVkdSBlbmcgZXNwIGV0YyBldGkgZmFyIGZsb2cgZm0gZm5kIGZvdCBmc3QgZzEyIGdnZiBnb3YgaW1iIGluZCBpbmYgam9yIGp1cyBsZWwgbWF0IG1lZCBtaWwgbXVzIG5ldCBub20gbm90IG50ciBvZG8gb3JnIHBwZyBwcm8gcHNjIHBzaSBxc2wgcmVjIHNsZyBzcnYgdG1wIHRyZCB0dXIgdHYgdmV0IHZsb2cgd2lraSB6bGcgJyxcbiAgICAgICdicyc6JyBjb20gZWR1IGdvdiBuZXQgb3JnICcsXG4gICAgICAnYnonOicgZHUgZXQgb20gb3YgcmcgJyxcbiAgICAgICdjYSc6JyBhYiBiYyBtYiBuYiBuZiBubCBucyBudCBudSBvbiBwZSBxYyBzayB5ayAnLFxuICAgICAgJ2NrJzonIGJpeiBjbyBlZHUgZ2VuIGdvdiBpbmZvIG5ldCBvcmcgJyxcbiAgICAgICdjbic6JyBhYyBhaCBiaiBjb20gY3EgZWR1IGZqIGdkIGdvdiBncyBneCBneiBoYSBoYiBoZSBoaSBobCBobiBqbCBqcyBqeCBsbiBtaWwgbmV0IG5tIG54IG9yZyBxaCBzYyBzZCBzaCBzbiBzeCB0aiB0dyB4aiB4eiB5biB6aiAnLFxuICAgICAgJ2NvJzonIGNvbSBlZHUgZ292IG1pbCBuZXQgbm9tIG9yZyAnLFxuICAgICAgJ2NyJzonIGFjIGMgY28gZWQgZmkgZ28gb3Igc2EgJyxcbiAgICAgICdjeSc6JyBhYyBiaXogY29tIGVrbG9nZXMgZ292IGx0ZCBuYW1lIG5ldCBvcmcgcGFybGlhbWVudCBwcmVzcyBwcm8gdG0gJyxcbiAgICAgICdkbyc6JyBhcnQgY29tIGVkdSBnb2IgZ292IG1pbCBuZXQgb3JnIHNsZCB3ZWIgJyxcbiAgICAgICdkeic6JyBhcnQgYXNzbyBjb20gZWR1IGdvdiBuZXQgb3JnIHBvbCAnLFxuICAgICAgJ2VjJzonIGNvbSBlZHUgZmluIGdvdiBpbmZvIG1lZCBtaWwgbmV0IG9yZyBwcm8gJyxcbiAgICAgICdlZyc6JyBjb20gZWR1IGV1biBnb3YgbWlsIG5hbWUgbmV0IG9yZyBzY2kgJyxcbiAgICAgICdlcic6JyBjb20gZWR1IGdvdiBpbmQgbWlsIG5ldCBvcmcgcm9jaGVzdCB3ICcsXG4gICAgICAnZXMnOicgY29tIGVkdSBnb2Igbm9tIG9yZyAnLFxuICAgICAgJ2V0JzonIGJpeiBjb20gZWR1IGdvdiBpbmZvIG5hbWUgbmV0IG9yZyAnLFxuICAgICAgJ2ZqJzonIGFjIGJpeiBjb20gaW5mbyBtaWwgbmFtZSBuZXQgb3JnIHBybyAnLFxuICAgICAgJ2ZrJzonIGFjIGNvIGdvdiBuZXQgbm9tIG9yZyAnLFxuICAgICAgJ2ZyJzonIGFzc28gY29tIGYgZ291diBub20gcHJkIHByZXNzZSB0bSAnLFxuICAgICAgJ2dnJzonIGNvIG5ldCBvcmcgJyxcbiAgICAgICdnaCc6JyBjb20gZWR1IGdvdiBtaWwgb3JnICcsXG4gICAgICAnZ24nOicgYWMgY29tIGdvdiBuZXQgb3JnICcsXG4gICAgICAnZ3InOicgY29tIGVkdSBnb3YgbWlsIG5ldCBvcmcgJyxcbiAgICAgICdndCc6JyBjb20gZWR1IGdvYiBpbmQgbWlsIG5ldCBvcmcgJyxcbiAgICAgICdndSc6JyBjb20gZWR1IGdvdiBuZXQgb3JnICcsXG4gICAgICAnaGsnOicgY29tIGVkdSBnb3YgaWR2IG5ldCBvcmcgJyxcbiAgICAgICdodSc6JyAyMDAwIGFncmFyIGJvbHQgY2FzaW5vIGNpdHkgY28gZXJvdGljYSBlcm90aWthIGZpbG0gZm9ydW0gZ2FtZXMgaG90ZWwgaW5mbyBpbmdhdGxhbiBqb2dhc3oga29ueXZlbG8gbGFrYXMgbWVkaWEgbmV3cyBvcmcgcHJpdiByZWtsYW0gc2V4IHNob3Agc3BvcnQgc3VsaSBzemV4IHRtIHRvenNkZSB1dGF6YXMgdmlkZW8gJyxcbiAgICAgICdpZCc6JyBhYyBjbyBnbyBtaWwgbmV0IG9yIHNjaCB3ZWIgJyxcbiAgICAgICdpbCc6JyBhYyBjbyBnb3YgaWRmIGsxMiBtdW5pIG5ldCBvcmcgJyxcbiAgICAgICdpbic6JyBhYyBjbyBlZHUgZXJuZXQgZmlybSBnZW4gZ292IGkgaW5kIG1pbCBuZXQgbmljIG9yZyByZXMgJyxcbiAgICAgICdpcSc6JyBjb20gZWR1IGdvdiBpIG1pbCBuZXQgb3JnICcsXG4gICAgICAnaXInOicgYWMgY28gZG5zc2VjIGdvdiBpIGlkIG5ldCBvcmcgc2NoICcsXG4gICAgICAnaXQnOicgZWR1IGdvdiAnLFxuICAgICAgJ2plJzonIGNvIG5ldCBvcmcgJyxcbiAgICAgICdqbyc6JyBjb20gZWR1IGdvdiBtaWwgbmFtZSBuZXQgb3JnIHNjaCAnLFxuICAgICAgJ2pwJzonIGFjIGFkIGNvIGVkIGdvIGdyIGxnIG5lIG9yICcsXG4gICAgICAna2UnOicgYWMgY28gZ28gaW5mbyBtZSBtb2JpIG5lIG9yIHNjICcsXG4gICAgICAna2gnOicgY29tIGVkdSBnb3YgbWlsIG5ldCBvcmcgcGVyICcsXG4gICAgICAna2knOicgYml6IGNvbSBkZSBlZHUgZ292IGluZm8gbW9iIG5ldCBvcmcgdGVsICcsXG4gICAgICAna20nOicgYXNzbyBjb20gY29vcCBlZHUgZ291diBrIG1lZGVjaW4gbWlsIG5vbSBub3RhaXJlcyBwaGFybWFjaWVucyBwcmVzc2UgdG0gdmV0ZXJpbmFpcmUgJyxcbiAgICAgICdrbic6JyBlZHUgZ292IG5ldCBvcmcgJyxcbiAgICAgICdrcic6JyBhYyBidXNhbiBjaHVuZ2J1ayBjaHVuZ25hbSBjbyBkYWVndSBkYWVqZW9uIGVzIGdhbmd3b24gZ28gZ3dhbmdqdSBneWVvbmdidWsgZ3llb25nZ2kgZ3llb25nbmFtIGhzIGluY2hlb24gamVqdSBqZW9uYnVrIGplb25uYW0gayBrZyBtaWwgbXMgbmUgb3IgcGUgcmUgc2Mgc2VvdWwgdWxzYW4gJyxcbiAgICAgICdrdyc6JyBjb20gZWR1IGdvdiBuZXQgb3JnICcsXG4gICAgICAna3knOicgY29tIGVkdSBnb3YgbmV0IG9yZyAnLFxuICAgICAgJ2t6JzonIGNvbSBlZHUgZ292IG1pbCBuZXQgb3JnICcsXG4gICAgICAnbGInOicgY29tIGVkdSBnb3YgbmV0IG9yZyAnLFxuICAgICAgJ2xrJzonIGFzc24gY29tIGVkdSBnb3YgZ3JwIGhvdGVsIGludCBsdGQgbmV0IG5nbyBvcmcgc2NoIHNvYyB3ZWIgJyxcbiAgICAgICdscic6JyBjb20gZWR1IGdvdiBuZXQgb3JnICcsXG4gICAgICAnbHYnOicgYXNuIGNvbSBjb25mIGVkdSBnb3YgaWQgbWlsIG5ldCBvcmcgJyxcbiAgICAgICdseSc6JyBjb20gZWR1IGdvdiBpZCBtZWQgbmV0IG9yZyBwbGMgc2NoICcsXG4gICAgICAnbWEnOicgYWMgY28gZ292IG0gbmV0IG9yZyBwcmVzcyAnLFxuICAgICAgJ21jJzonIGFzc28gdG0gJyxcbiAgICAgICdtZSc6JyBhYyBjbyBlZHUgZ292IGl0cyBuZXQgb3JnIHByaXYgJyxcbiAgICAgICdtZyc6JyBjb20gZWR1IGdvdiBtaWwgbm9tIG9yZyBwcmQgdG0gJyxcbiAgICAgICdtayc6JyBjb20gZWR1IGdvdiBpbmYgbmFtZSBuZXQgb3JnIHBybyAnLFxuICAgICAgJ21sJzonIGNvbSBlZHUgZ292IG5ldCBvcmcgcHJlc3NlICcsXG4gICAgICAnbW4nOicgZWR1IGdvdiBvcmcgJyxcbiAgICAgICdtbyc6JyBjb20gZWR1IGdvdiBuZXQgb3JnICcsXG4gICAgICAnbXQnOicgY29tIGVkdSBnb3YgbmV0IG9yZyAnLFxuICAgICAgJ212JzonIGFlcm8gYml6IGNvbSBjb29wIGVkdSBnb3YgaW5mbyBpbnQgbWlsIG11c2V1bSBuYW1lIG5ldCBvcmcgcHJvICcsXG4gICAgICAnbXcnOicgYWMgY28gY29tIGNvb3AgZWR1IGdvdiBpbnQgbXVzZXVtIG5ldCBvcmcgJyxcbiAgICAgICdteCc6JyBjb20gZWR1IGdvYiBuZXQgb3JnICcsXG4gICAgICAnbXknOicgY29tIGVkdSBnb3YgbWlsIG5hbWUgbmV0IG9yZyBzY2ggJyxcbiAgICAgICduZic6JyBhcnRzIGNvbSBmaXJtIGluZm8gbmV0IG90aGVyIHBlciByZWMgc3RvcmUgd2ViICcsXG4gICAgICAnbmcnOicgYml6IGNvbSBlZHUgZ292IG1pbCBtb2JpIG5hbWUgbmV0IG9yZyBzY2ggJyxcbiAgICAgICduaSc6JyBhYyBjbyBjb20gZWR1IGdvYiBtaWwgbmV0IG5vbSBvcmcgJyxcbiAgICAgICducCc6JyBjb20gZWR1IGdvdiBtaWwgbmV0IG9yZyAnLFxuICAgICAgJ25yJzonIGJpeiBjb20gZWR1IGdvdiBpbmZvIG5ldCBvcmcgJyxcbiAgICAgICdvbSc6JyBhYyBiaXogY28gY29tIGVkdSBnb3YgbWVkIG1pbCBtdXNldW0gbmV0IG9yZyBwcm8gc2NoICcsXG4gICAgICAncGUnOicgY29tIGVkdSBnb2IgbWlsIG5ldCBub20gb3JnIHNsZCAnLFxuICAgICAgJ3BoJzonIGNvbSBlZHUgZ292IGkgbWlsIG5ldCBuZ28gb3JnICcsXG4gICAgICAncGsnOicgYml6IGNvbSBlZHUgZmFtIGdvYiBnb2sgZ29uIGdvcCBnb3MgZ292IG5ldCBvcmcgd2ViICcsXG4gICAgICAncGwnOicgYXJ0IGJpYWx5c3RvayBiaXogY29tIGVkdSBnZGEgZ2RhbnNrIGdvcnpvdyBnb3YgaW5mbyBrYXRvd2ljZSBrcmFrb3cgbG9keiBsdWJsaW4gbWlsIG5ldCBuZ28gb2xzenR5biBvcmcgcG96bmFuIHB3ciByYWRvbSBzbHVwc2sgc3pjemVjaW4gdG9ydW4gd2Fyc3phd2Egd2F3IHdyb2Mgd3JvY2xhdyB6Z29yYSAnLFxuICAgICAgJ3ByJzonIGFjIGJpeiBjb20gZWR1IGVzdCBnb3YgaW5mbyBpc2xhIG5hbWUgbmV0IG9yZyBwcm8gcHJvZiAnLFxuICAgICAgJ3BzJzonIGNvbSBlZHUgZ292IG5ldCBvcmcgcGxvIHNlYyAnLFxuICAgICAgJ3B3JzonIGJlbGF1IGNvIGVkIGdvIG5lIG9yICcsXG4gICAgICAncm8nOicgYXJ0cyBjb20gZmlybSBpbmZvIG5vbSBudCBvcmcgcmVjIHN0b3JlIHRtIHd3dyAnLFxuICAgICAgJ3JzJzonIGFjIGNvIGVkdSBnb3YgaW4gb3JnICcsXG4gICAgICAnc2InOicgY29tIGVkdSBnb3YgbmV0IG9yZyAnLFxuICAgICAgJ3NjJzonIGNvbSBlZHUgZ292IG5ldCBvcmcgJyxcbiAgICAgICdzaCc6JyBjbyBjb20gZWR1IGdvdiBuZXQgbm9tIG9yZyAnLFxuICAgICAgJ3NsJzonIGNvbSBlZHUgZ292IG5ldCBvcmcgJyxcbiAgICAgICdzdCc6JyBjbyBjb20gY29uc3VsYWRvIGVkdSBlbWJhaXhhZGEgZ292IG1pbCBuZXQgb3JnIHByaW5jaXBlIHNhb3RvbWUgc3RvcmUgJyxcbiAgICAgICdzdic6JyBjb20gZWR1IGdvYiBvcmcgcmVkICcsXG4gICAgICAnc3onOicgYWMgY28gb3JnICcsXG4gICAgICAndHInOicgYXYgYmJzIGJlbCBiaXogY29tIGRyIGVkdSBnZW4gZ292IGluZm8gazEyIG5hbWUgbmV0IG9yZyBwb2wgdGVsIHRzayB0diB3ZWIgJyxcbiAgICAgICd0dCc6JyBhZXJvIGJpeiBjYXQgY28gY29tIGNvb3AgZWR1IGdvdiBpbmZvIGludCBqb2JzIG1pbCBtb2JpIG11c2V1bSBuYW1lIG5ldCBvcmcgcHJvIHRlbCB0cmF2ZWwgJyxcbiAgICAgICd0dyc6JyBjbHViIGNvbSBlYml6IGVkdSBnYW1lIGdvdiBpZHYgbWlsIG5ldCBvcmcgJyxcbiAgICAgICdtdSc6JyBhYyBjbyBjb20gZ292IG5ldCBvciBvcmcgJyxcbiAgICAgICdteic6JyBhYyBjbyBlZHUgZ292IG9yZyAnLFxuICAgICAgJ25hJzonIGNvIGNvbSAnLFxuICAgICAgJ256JzonIGFjIGNvIGNyaSBnZWVrIGdlbiBnb3Z0IGhlYWx0aCBpd2kgbWFvcmkgbWlsIG5ldCBvcmcgcGFybGlhbWVudCBzY2hvb2wgJyxcbiAgICAgICdwYSc6JyBhYm8gYWMgY29tIGVkdSBnb2IgaW5nIG1lZCBuZXQgbm9tIG9yZyBzbGQgJyxcbiAgICAgICdwdCc6JyBjb20gZWR1IGdvdiBpbnQgbmV0IG5vbWUgb3JnIHB1YmwgJyxcbiAgICAgICdweSc6JyBjb20gZWR1IGdvdiBtaWwgbmV0IG9yZyAnLFxuICAgICAgJ3FhJzonIGNvbSBlZHUgZ292IG1pbCBuZXQgb3JnICcsXG4gICAgICAncmUnOicgYXNzbyBjb20gbm9tICcsXG4gICAgICAncnUnOicgYWMgYWR5Z2V5YSBhbHRhaSBhbXVyIGFya2hhbmdlbHNrIGFzdHJha2hhbiBiYXNoa2lyaWEgYmVsZ29yb2QgYmlyIGJyeWFuc2sgYnVyeWF0aWEgY2JnIGNoZWwgY2hlbHlhYmluc2sgY2hpdGEgY2h1a290a2EgY2h1dmFzaGlhIGNvbSBkYWdlc3RhbiBlLWJ1cmcgZWR1IGdvdiBncm96bnkgaW50IGlya3V0c2sgaXZhbm92byBpemhldnNrIGphciBqb3Noa2FyLW9sYSBrYWxteWtpYSBrYWx1Z2Ega2FtY2hhdGthIGthcmVsaWEga2F6YW4ga2NociBrZW1lcm92byBraGFiYXJvdnNrIGtoYWthc3NpYSBraHYga2lyb3Yga29lbmlnIGtvbWkga29zdHJvbWEga3Jhbm95YXJzayBrdWJhbiBrdXJnYW4ga3Vyc2sgbGlwZXRzayBtYWdhZGFuIG1hcmkgbWFyaS1lbCBtYXJpbmUgbWlsIG1vcmRvdmlhIG1vc3JlZyBtc2sgbXVybWFuc2sgbmFsY2hpayBuZXQgbm5vdiBub3Ygbm92b3NpYmlyc2sgbnNrIG9tc2sgb3JlbmJ1cmcgb3JnIG9yeW9sIHBlbnphIHBlcm0gcHAgcHNrb3YgcHR6IHJuZCByeWF6YW4gc2FraGFsaW4gc2FtYXJhIHNhcmF0b3Ygc2ltYmlyc2sgc21vbGVuc2sgc3BiIHN0YXZyb3BvbCBzdHYgc3VyZ3V0IHRhbWJvdiB0YXRhcnN0YW4gdG9tIHRvbXNrIHRzYXJpdHN5biB0c2sgdHVsYSB0dXZhIHR2ZXIgdHl1bWVuIHVkbSB1ZG11cnRpYSB1bGFuLXVkZSB2bGFkaWthdmtheiB2bGFkaW1pciB2bGFkaXZvc3RvayB2b2xnb2dyYWQgdm9sb2dkYSB2b3JvbmV6aCB2cm4gdnlhdGthIHlha3V0aWEgeWFtYWwgeWVrYXRlcmluYnVyZyB5dXpobm8tc2FraGFsaW5zayAnLFxuICAgICAgJ3J3JzonIGFjIGNvIGNvbSBlZHUgZ291diBnb3YgaW50IG1pbCBuZXQgJyxcbiAgICAgICdzYSc6JyBjb20gZWR1IGdvdiBtZWQgbmV0IG9yZyBwdWIgc2NoICcsXG4gICAgICAnc2QnOicgY29tIGVkdSBnb3YgaW5mbyBtZWQgbmV0IG9yZyB0diAnLFxuICAgICAgJ3NlJzonIGEgYWMgYiBiZCBjIGQgZSBmIGcgaCBpIGsgbCBtIG4gbyBvcmcgcCBwYXJ0aSBwcCBwcmVzcyByIHMgdCB0bSB1IHcgeCB5IHogJyxcbiAgICAgICdzZyc6JyBjb20gZWR1IGdvdiBpZG4gbmV0IG9yZyBwZXIgJyxcbiAgICAgICdzbic6JyBhcnQgY29tIGVkdSBnb3V2IG9yZyBwZXJzbyB1bml2ICcsXG4gICAgICAnc3knOicgY29tIGVkdSBnb3YgbWlsIG5ldCBuZXdzIG9yZyAnLFxuICAgICAgJ3RoJzonIGFjIGNvIGdvIGluIG1pIG5ldCBvciAnLFxuICAgICAgJ3RqJzonIGFjIGJpeiBjbyBjb20gZWR1IGdvIGdvdiBpbmZvIGludCBtaWwgbmFtZSBuZXQgbmljIG9yZyB0ZXN0IHdlYiAnLFxuICAgICAgJ3RuJzonIGFncmluZXQgY29tIGRlZmVuc2UgZWR1bmV0IGVucyBmaW4gZ292IGluZCBpbmZvIGludGwgbWluY29tIG5hdCBuZXQgb3JnIHBlcnNvIHJucnQgcm5zIHJudSB0b3VyaXNtICcsXG4gICAgICAndHonOicgYWMgY28gZ28gbmUgb3IgJyxcbiAgICAgICd1YSc6JyBiaXogY2hlcmthc3N5IGNoZXJuaWdvdiBjaGVybm92dHN5IGNrIGNuIGNvIGNvbSBjcmltZWEgY3YgZG4gZG5lcHJvcGV0cm92c2sgZG9uZXRzayBkcCBlZHUgZ292IGlmIGluIGl2YW5vLWZyYW5raXZzayBraCBraGFya292IGtoZXJzb24ga2htZWxuaXRza2l5IGtpZXYga2lyb3ZvZ3JhZCBrbSBrciBrcyBrdiBsZyBsdWdhbnNrIGx1dHNrIGx2aXYgbWUgbWsgbmV0IG5pa29sYWV2IG9kIG9kZXNzYSBvcmcgcGwgcG9sdGF2YSBwcCByb3ZubyBydiBzZWJhc3RvcG9sIHN1bXkgdGUgdGVybm9waWwgdXpoZ29yb2QgdmlubmljYSB2biB6YXBvcml6aHpoZSB6aGl0b21pciB6cCB6dCAnLFxuICAgICAgJ3VnJzonIGFjIGNvIGdvIG5lIG9yIG9yZyBzYyAnLFxuICAgICAgJ3VrJzonIGFjIGJsIGJyaXRpc2gtbGlicmFyeSBjbyBjeW0gZ292IGdvdnQgaWNuZXQgamV0IGxlYSBsdGQgbWUgbWlsIG1vZCBuYXRpb25hbC1saWJyYXJ5LXNjb3RsYW5kIG5lbCBuZXQgbmhzIG5pYyBubHMgb3JnIG9yZ24gcGFybGlhbWVudCBwbGMgcG9saWNlIHNjaCBzY290IHNvYyAnLFxuICAgICAgJ3VzJzonIGRuaSBmZWQgaXNhIGtpZHMgbnNuICcsXG4gICAgICAndXknOicgY29tIGVkdSBndWIgbWlsIG5ldCBvcmcgJyxcbiAgICAgICd2ZSc6JyBjbyBjb20gZWR1IGdvYiBpbmZvIG1pbCBuZXQgb3JnIHdlYiAnLFxuICAgICAgJ3ZpJzonIGNvIGNvbSBrMTIgbmV0IG9yZyAnLFxuICAgICAgJ3ZuJzonIGFjIGJpeiBjb20gZWR1IGdvdiBoZWFsdGggaW5mbyBpbnQgbmFtZSBuZXQgb3JnIHBybyAnLFxuICAgICAgJ3llJzonIGNvIGNvbSBnb3YgbHRkIG1lIG5ldCBvcmcgcGxjICcsXG4gICAgICAneXUnOicgYWMgY28gZWR1IGdvdiBvcmcgJyxcbiAgICAgICd6YSc6JyBhYyBhZ3JpYyBhbHQgYm91cnNlIGNpdHkgY28gY3liZXJuZXQgZGIgZWR1IGdvdiBncm9uZGFyIGlhY2Nlc3MgaW10IGluY2EgbGFuZGVzaWduIGxhdyBtaWwgbmV0IG5nbyBuaXMgbm9tIG9saXZldHRpIG9yZyBwaXggc2Nob29sIHRtIHdlYiAnLFxuICAgICAgJ3ptJzonIGFjIGNvIGNvbSBlZHUgZ292IG5ldCBvcmcgc2NoICdcbiAgICB9LFxuICAgIC8vIGdvcmhpbGwgMjAxMy0xMC0yNTogVXNpbmcgaW5kZXhPZigpIGluc3RlYWQgUmVnZXhwKCkuIFNpZ25pZmljYW50IGJvb3N0XG4gICAgLy8gaW4gYm90aCBwZXJmb3JtYW5jZSBhbmQgbWVtb3J5IGZvb3RwcmludC4gTm8gaW5pdGlhbGl6YXRpb24gcmVxdWlyZWQuXG4gICAgLy8gaHR0cDovL2pzcGVyZi5jb20vdXJpLWpzLXNsZC1yZWdleC12cy1iaW5hcnktc2VhcmNoLzRcbiAgICAvLyBGb2xsb3dpbmcgbWV0aG9kcyB1c2UgbGFzdEluZGV4T2YoKSByYXRoZXIgdGhhbiBhcnJheS5zcGxpdCgpIGluIG9yZGVyXG4gICAgLy8gdG8gYXZvaWQgYW55IG1lbW9yeSBhbGxvY2F0aW9ucy5cbiAgICBoYXM6IGZ1bmN0aW9uKGRvbWFpbikge1xuICAgICAgdmFyIHRsZE9mZnNldCA9IGRvbWFpbi5sYXN0SW5kZXhPZignLicpO1xuICAgICAgaWYgKHRsZE9mZnNldCA8PSAwIHx8IHRsZE9mZnNldCA+PSAoZG9tYWluLmxlbmd0aC0xKSkge1xuICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICB9XG4gICAgICB2YXIgc2xkT2Zmc2V0ID0gZG9tYWluLmxhc3RJbmRleE9mKCcuJywgdGxkT2Zmc2V0LTEpO1xuICAgICAgaWYgKHNsZE9mZnNldCA8PSAwIHx8IHNsZE9mZnNldCA+PSAodGxkT2Zmc2V0LTEpKSB7XG4gICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgIH1cbiAgICAgIHZhciBzbGRMaXN0ID0gU0xELmxpc3RbZG9tYWluLnNsaWNlKHRsZE9mZnNldCsxKV07XG4gICAgICBpZiAoIXNsZExpc3QpIHtcbiAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgfVxuICAgICAgcmV0dXJuIHNsZExpc3QuaW5kZXhPZignICcgKyBkb21haW4uc2xpY2Uoc2xkT2Zmc2V0KzEsIHRsZE9mZnNldCkgKyAnICcpID49IDA7XG4gICAgfSxcbiAgICBpczogZnVuY3Rpb24oZG9tYWluKSB7XG4gICAgICB2YXIgdGxkT2Zmc2V0ID0gZG9tYWluLmxhc3RJbmRleE9mKCcuJyk7XG4gICAgICBpZiAodGxkT2Zmc2V0IDw9IDAgfHwgdGxkT2Zmc2V0ID49IChkb21haW4ubGVuZ3RoLTEpKSB7XG4gICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgIH1cbiAgICAgIHZhciBzbGRPZmZzZXQgPSBkb21haW4ubGFzdEluZGV4T2YoJy4nLCB0bGRPZmZzZXQtMSk7XG4gICAgICBpZiAoc2xkT2Zmc2V0ID49IDApIHtcbiAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgfVxuICAgICAgdmFyIHNsZExpc3QgPSBTTEQubGlzdFtkb21haW4uc2xpY2UodGxkT2Zmc2V0KzEpXTtcbiAgICAgIGlmICghc2xkTGlzdCkge1xuICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICB9XG4gICAgICByZXR1cm4gc2xkTGlzdC5pbmRleE9mKCcgJyArIGRvbWFpbi5zbGljZSgwLCB0bGRPZmZzZXQpICsgJyAnKSA+PSAwO1xuICAgIH0sXG4gICAgZ2V0OiBmdW5jdGlvbihkb21haW4pIHtcbiAgICAgIHZhciB0bGRPZmZzZXQgPSBkb21haW4ubGFzdEluZGV4T2YoJy4nKTtcbiAgICAgIGlmICh0bGRPZmZzZXQgPD0gMCB8fCB0bGRPZmZzZXQgPj0gKGRvbWFpbi5sZW5ndGgtMSkpIHtcbiAgICAgICAgcmV0dXJuIG51bGw7XG4gICAgICB9XG4gICAgICB2YXIgc2xkT2Zmc2V0ID0gZG9tYWluLmxhc3RJbmRleE9mKCcuJywgdGxkT2Zmc2V0LTEpO1xuICAgICAgaWYgKHNsZE9mZnNldCA8PSAwIHx8IHNsZE9mZnNldCA+PSAodGxkT2Zmc2V0LTEpKSB7XG4gICAgICAgIHJldHVybiBudWxsO1xuICAgICAgfVxuICAgICAgdmFyIHNsZExpc3QgPSBTTEQubGlzdFtkb21haW4uc2xpY2UodGxkT2Zmc2V0KzEpXTtcbiAgICAgIGlmICghc2xkTGlzdCkge1xuICAgICAgICByZXR1cm4gbnVsbDtcbiAgICAgIH1cbiAgICAgIGlmIChzbGRMaXN0LmluZGV4T2YoJyAnICsgZG9tYWluLnNsaWNlKHNsZE9mZnNldCsxLCB0bGRPZmZzZXQpICsgJyAnKSA8IDApIHtcbiAgICAgICAgcmV0dXJuIG51bGw7XG4gICAgICB9XG4gICAgICByZXR1cm4gZG9tYWluLnNsaWNlKHNsZE9mZnNldCsxKTtcbiAgICB9LFxuICAgIG5vQ29uZmxpY3Q6IGZ1bmN0aW9uKCl7XG4gICAgICBpZiAocm9vdC5TZWNvbmRMZXZlbERvbWFpbnMgPT09IHRoaXMpIHtcbiAgICAgICAgcm9vdC5TZWNvbmRMZXZlbERvbWFpbnMgPSBfU2Vjb25kTGV2ZWxEb21haW5zO1xuICAgICAgfVxuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfVxuICB9O1xuXG4gIHJldHVybiBTTEQ7XG59KSk7XG4iLCIvKiFcbiAqIFVSSS5qcyAtIE11dGF0aW5nIFVSTHNcbiAqXG4gKiBWZXJzaW9uOiAxLjE3LjBcbiAqXG4gKiBBdXRob3I6IFJvZG5leSBSZWhtXG4gKiBXZWI6IGh0dHA6Ly9tZWRpYWxpemUuZ2l0aHViLmlvL1VSSS5qcy9cbiAqXG4gKiBMaWNlbnNlZCB1bmRlclxuICogICBNSVQgTGljZW5zZSBodHRwOi8vd3d3Lm9wZW5zb3VyY2Uub3JnL2xpY2Vuc2VzL21pdC1saWNlbnNlXG4gKiAgIEdQTCB2MyBodHRwOi8vb3BlbnNvdXJjZS5vcmcvbGljZW5zZXMvR1BMLTMuMFxuICpcbiAqL1xuKGZ1bmN0aW9uIChyb290LCBmYWN0b3J5KSB7XG4gICd1c2Ugc3RyaWN0JztcbiAgLy8gaHR0cHM6Ly9naXRodWIuY29tL3VtZGpzL3VtZC9ibG9iL21hc3Rlci9yZXR1cm5FeHBvcnRzLmpzXG4gIGlmICh0eXBlb2YgZXhwb3J0cyA9PT0gJ29iamVjdCcpIHtcbiAgICAvLyBOb2RlXG4gICAgbW9kdWxlLmV4cG9ydHMgPSBmYWN0b3J5KHJlcXVpcmUoJy4vcHVueWNvZGUnKSwgcmVxdWlyZSgnLi9JUHY2JyksIHJlcXVpcmUoJy4vU2Vjb25kTGV2ZWxEb21haW5zJykpO1xuICB9IGVsc2UgaWYgKHR5cGVvZiBkZWZpbmUgPT09ICdmdW5jdGlvbicgJiYgZGVmaW5lLmFtZCkge1xuICAgIC8vIEFNRC4gUmVnaXN0ZXIgYXMgYW4gYW5vbnltb3VzIG1vZHVsZS5cbiAgICBkZWZpbmUoWycuL3B1bnljb2RlJywgJy4vSVB2NicsICcuL1NlY29uZExldmVsRG9tYWlucyddLCBmYWN0b3J5KTtcbiAgfSBlbHNlIHtcbiAgICAvLyBCcm93c2VyIGdsb2JhbHMgKHJvb3QgaXMgd2luZG93KVxuICAgIHJvb3QuVVJJID0gZmFjdG9yeShyb290LnB1bnljb2RlLCByb290LklQdjYsIHJvb3QuU2Vjb25kTGV2ZWxEb21haW5zLCByb290KTtcbiAgfVxufSh0aGlzLCBmdW5jdGlvbiAocHVueWNvZGUsIElQdjYsIFNMRCwgcm9vdCkge1xuICAndXNlIHN0cmljdCc7XG4gIC8qZ2xvYmFsIGxvY2F0aW9uLCBlc2NhcGUsIHVuZXNjYXBlICovXG4gIC8vIEZJWE1FOiB2Mi4wLjAgcmVuYW1jZSBub24tY2FtZWxDYXNlIHByb3BlcnRpZXMgdG8gdXBwZXJjYXNlXG4gIC8qanNoaW50IGNhbWVsY2FzZTogZmFsc2UgKi9cblxuICAvLyBzYXZlIGN1cnJlbnQgVVJJIHZhcmlhYmxlLCBpZiBhbnlcbiAgdmFyIF9VUkkgPSByb290ICYmIHJvb3QuVVJJO1xuXG4gIGZ1bmN0aW9uIFVSSSh1cmwsIGJhc2UpIHtcbiAgICB2YXIgX3VybFN1cHBsaWVkID0gYXJndW1lbnRzLmxlbmd0aCA+PSAxO1xuICAgIHZhciBfYmFzZVN1cHBsaWVkID0gYXJndW1lbnRzLmxlbmd0aCA+PSAyO1xuXG4gICAgLy8gQWxsb3cgaW5zdGFudGlhdGlvbiB3aXRob3V0IHRoZSAnbmV3JyBrZXl3b3JkXG4gICAgaWYgKCEodGhpcyBpbnN0YW5jZW9mIFVSSSkpIHtcbiAgICAgIGlmIChfdXJsU3VwcGxpZWQpIHtcbiAgICAgICAgaWYgKF9iYXNlU3VwcGxpZWQpIHtcbiAgICAgICAgICByZXR1cm4gbmV3IFVSSSh1cmwsIGJhc2UpO1xuICAgICAgICB9XG5cbiAgICAgICAgcmV0dXJuIG5ldyBVUkkodXJsKTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIG5ldyBVUkkoKTtcbiAgICB9XG5cbiAgICBpZiAodXJsID09PSB1bmRlZmluZWQpIHtcbiAgICAgIGlmIChfdXJsU3VwcGxpZWQpIHtcbiAgICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcigndW5kZWZpbmVkIGlzIG5vdCBhIHZhbGlkIGFyZ3VtZW50IGZvciBVUkknKTtcbiAgICAgIH1cblxuICAgICAgaWYgKHR5cGVvZiBsb2NhdGlvbiAhPT0gJ3VuZGVmaW5lZCcpIHtcbiAgICAgICAgdXJsID0gbG9jYXRpb24uaHJlZiArICcnO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdXJsID0gJyc7XG4gICAgICB9XG4gICAgfVxuXG4gICAgdGhpcy5ocmVmKHVybCk7XG5cbiAgICAvLyByZXNvbHZlIHRvIGJhc2UgYWNjb3JkaW5nIHRvIGh0dHA6Ly9kdmNzLnczLm9yZy9oZy91cmwvcmF3LWZpbGUvdGlwL092ZXJ2aWV3Lmh0bWwjY29uc3RydWN0b3JcbiAgICBpZiAoYmFzZSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICByZXR1cm4gdGhpcy5hYnNvbHV0ZVRvKGJhc2UpO1xuICAgIH1cblxuICAgIHJldHVybiB0aGlzO1xuICB9XG5cbiAgVVJJLnZlcnNpb24gPSAnMS4xNy4wJztcblxuICB2YXIgcCA9IFVSSS5wcm90b3R5cGU7XG4gIHZhciBoYXNPd24gPSBPYmplY3QucHJvdG90eXBlLmhhc093blByb3BlcnR5O1xuXG4gIGZ1bmN0aW9uIGVzY2FwZVJlZ0V4KHN0cmluZykge1xuICAgIC8vIGh0dHBzOi8vZ2l0aHViLmNvbS9tZWRpYWxpemUvVVJJLmpzL2NvbW1pdC84NWFjMjE3ODNjMTFmOGNjYWIwNjEwNmRiYTk3MzVhMzFhODY5MjRkI2NvbW1pdGNvbW1lbnQtODIxOTYzXG4gICAgcmV0dXJuIHN0cmluZy5yZXBsYWNlKC8oWy4qKz9ePSE6JHt9KCl8W1xcXVxcL1xcXFxdKS9nLCAnXFxcXCQxJyk7XG4gIH1cblxuICBmdW5jdGlvbiBnZXRUeXBlKHZhbHVlKSB7XG4gICAgLy8gSUU4IGRvZXNuJ3QgcmV0dXJuIFtPYmplY3QgVW5kZWZpbmVkXSBidXQgW09iamVjdCBPYmplY3RdIGZvciB1bmRlZmluZWQgdmFsdWVcbiAgICBpZiAodmFsdWUgPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuICdVbmRlZmluZWQnO1xuICAgIH1cblxuICAgIHJldHVybiBTdHJpbmcoT2JqZWN0LnByb3RvdHlwZS50b1N0cmluZy5jYWxsKHZhbHVlKSkuc2xpY2UoOCwgLTEpO1xuICB9XG5cbiAgZnVuY3Rpb24gaXNBcnJheShvYmopIHtcbiAgICByZXR1cm4gZ2V0VHlwZShvYmopID09PSAnQXJyYXknO1xuICB9XG5cbiAgZnVuY3Rpb24gZmlsdGVyQXJyYXlWYWx1ZXMoZGF0YSwgdmFsdWUpIHtcbiAgICB2YXIgbG9va3VwID0ge307XG4gICAgdmFyIGksIGxlbmd0aDtcblxuICAgIGlmIChnZXRUeXBlKHZhbHVlKSA9PT0gJ1JlZ0V4cCcpIHtcbiAgICAgIGxvb2t1cCA9IG51bGw7XG4gICAgfSBlbHNlIGlmIChpc0FycmF5KHZhbHVlKSkge1xuICAgICAgZm9yIChpID0gMCwgbGVuZ3RoID0gdmFsdWUubGVuZ3RoOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgICAgbG9va3VwW3ZhbHVlW2ldXSA9IHRydWU7XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIGxvb2t1cFt2YWx1ZV0gPSB0cnVlO1xuICAgIH1cblxuICAgIGZvciAoaSA9IDAsIGxlbmd0aCA9IGRhdGEubGVuZ3RoOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgIC8qanNoaW50IGxheGJyZWFrOiB0cnVlICovXG4gICAgICB2YXIgX21hdGNoID0gbG9va3VwICYmIGxvb2t1cFtkYXRhW2ldXSAhPT0gdW5kZWZpbmVkXG4gICAgICAgIHx8ICFsb29rdXAgJiYgdmFsdWUudGVzdChkYXRhW2ldKTtcbiAgICAgIC8qanNoaW50IGxheGJyZWFrOiBmYWxzZSAqL1xuICAgICAgaWYgKF9tYXRjaCkge1xuICAgICAgICBkYXRhLnNwbGljZShpLCAxKTtcbiAgICAgICAgbGVuZ3RoLS07XG4gICAgICAgIGktLTtcbiAgICAgIH1cbiAgICB9XG5cbiAgICByZXR1cm4gZGF0YTtcbiAgfVxuXG4gIGZ1bmN0aW9uIGFycmF5Q29udGFpbnMobGlzdCwgdmFsdWUpIHtcbiAgICB2YXIgaSwgbGVuZ3RoO1xuXG4gICAgLy8gdmFsdWUgbWF5IGJlIHN0cmluZywgbnVtYmVyLCBhcnJheSwgcmVnZXhwXG4gICAgaWYgKGlzQXJyYXkodmFsdWUpKSB7XG4gICAgICAvLyBOb3RlOiB0aGlzIGNhbiBiZSBvcHRpbWl6ZWQgdG8gTyhuKSAoaW5zdGVhZCBvZiBjdXJyZW50IE8obSAqIG4pKVxuICAgICAgZm9yIChpID0gMCwgbGVuZ3RoID0gdmFsdWUubGVuZ3RoOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgICAgaWYgKCFhcnJheUNvbnRhaW5zKGxpc3QsIHZhbHVlW2ldKSkge1xuICAgICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgICAgfVxuICAgICAgfVxuXG4gICAgICByZXR1cm4gdHJ1ZTtcbiAgICB9XG5cbiAgICB2YXIgX3R5cGUgPSBnZXRUeXBlKHZhbHVlKTtcbiAgICBmb3IgKGkgPSAwLCBsZW5ndGggPSBsaXN0Lmxlbmd0aDsgaSA8IGxlbmd0aDsgaSsrKSB7XG4gICAgICBpZiAoX3R5cGUgPT09ICdSZWdFeHAnKSB7XG4gICAgICAgIGlmICh0eXBlb2YgbGlzdFtpXSA9PT0gJ3N0cmluZycgJiYgbGlzdFtpXS5tYXRjaCh2YWx1ZSkpIHtcbiAgICAgICAgICByZXR1cm4gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIGlmIChsaXN0W2ldID09PSB2YWx1ZSkge1xuICAgICAgICByZXR1cm4gdHJ1ZTtcbiAgICAgIH1cbiAgICB9XG5cbiAgICByZXR1cm4gZmFsc2U7XG4gIH1cblxuICBmdW5jdGlvbiBhcnJheXNFcXVhbChvbmUsIHR3bykge1xuICAgIGlmICghaXNBcnJheShvbmUpIHx8ICFpc0FycmF5KHR3bykpIHtcbiAgICAgIHJldHVybiBmYWxzZTtcbiAgICB9XG5cbiAgICAvLyBhcnJheXMgY2FuJ3QgYmUgZXF1YWwgaWYgdGhleSBoYXZlIGRpZmZlcmVudCBhbW91bnQgb2YgY29udGVudFxuICAgIGlmIChvbmUubGVuZ3RoICE9PSB0d28ubGVuZ3RoKSB7XG4gICAgICByZXR1cm4gZmFsc2U7XG4gICAgfVxuXG4gICAgb25lLnNvcnQoKTtcbiAgICB0d28uc29ydCgpO1xuXG4gICAgZm9yICh2YXIgaSA9IDAsIGwgPSBvbmUubGVuZ3RoOyBpIDwgbDsgaSsrKSB7XG4gICAgICBpZiAob25lW2ldICE9PSB0d29baV0pIHtcbiAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgfVxuICAgIH1cblxuICAgIHJldHVybiB0cnVlO1xuICB9XG5cbiAgZnVuY3Rpb24gdHJpbVNsYXNoZXModGV4dCkge1xuICAgIHZhciB0cmltX2V4cHJlc3Npb24gPSAvXlxcLyt8XFwvKyQvZztcbiAgICByZXR1cm4gdGV4dC5yZXBsYWNlKHRyaW1fZXhwcmVzc2lvbiwgJycpO1xuICB9XG5cbiAgVVJJLl9wYXJ0cyA9IGZ1bmN0aW9uKCkge1xuICAgIHJldHVybiB7XG4gICAgICBwcm90b2NvbDogbnVsbCxcbiAgICAgIHVzZXJuYW1lOiBudWxsLFxuICAgICAgcGFzc3dvcmQ6IG51bGwsXG4gICAgICBob3N0bmFtZTogbnVsbCxcbiAgICAgIHVybjogbnVsbCxcbiAgICAgIHBvcnQ6IG51bGwsXG4gICAgICBwYXRoOiBudWxsLFxuICAgICAgcXVlcnk6IG51bGwsXG4gICAgICBmcmFnbWVudDogbnVsbCxcbiAgICAgIC8vIHN0YXRlXG4gICAgICBkdXBsaWNhdGVRdWVyeVBhcmFtZXRlcnM6IFVSSS5kdXBsaWNhdGVRdWVyeVBhcmFtZXRlcnMsXG4gICAgICBlc2NhcGVRdWVyeVNwYWNlOiBVUkkuZXNjYXBlUXVlcnlTcGFjZVxuICAgIH07XG4gIH07XG4gIC8vIHN0YXRlOiBhbGxvdyBkdXBsaWNhdGUgcXVlcnkgcGFyYW1ldGVycyAoYT0xJmE9MSlcbiAgVVJJLmR1cGxpY2F0ZVF1ZXJ5UGFyYW1ldGVycyA9IGZhbHNlO1xuICAvLyBzdGF0ZTogcmVwbGFjZXMgKyB3aXRoICUyMCAoc3BhY2UgaW4gcXVlcnkgc3RyaW5ncylcbiAgVVJJLmVzY2FwZVF1ZXJ5U3BhY2UgPSB0cnVlO1xuICAvLyBzdGF0aWMgcHJvcGVydGllc1xuICBVUkkucHJvdG9jb2xfZXhwcmVzc2lvbiA9IC9eW2Etel1bYS16MC05ListXSokL2k7XG4gIFVSSS5pZG5fZXhwcmVzc2lvbiA9IC9bXmEtejAtOVxcLi1dL2k7XG4gIFVSSS5wdW55Y29kZV9leHByZXNzaW9uID0gLyh4bi0tKS9pO1xuICAvLyB3ZWxsLCAzMzMuNDQ0LjU1NS42NjYgbWF0Y2hlcywgYnV0IGl0IHN1cmUgYWluJ3Qgbm8gSVB2NCAtIGRvIHdlIGNhcmU/XG4gIFVSSS5pcDRfZXhwcmVzc2lvbiA9IC9eXFxkezEsM31cXC5cXGR7MSwzfVxcLlxcZHsxLDN9XFwuXFxkezEsM30kLztcbiAgLy8gY3JlZGl0cyB0byBSaWNoIEJyb3duXG4gIC8vIHNvdXJjZTogaHR0cDovL2ZvcnVtcy5pbnRlcm1hcHBlci5jb20vdmlld3RvcGljLnBocD9wPTEwOTYjMTA5NlxuICAvLyBzcGVjaWZpY2F0aW9uOiBodHRwOi8vd3d3LmlldGYub3JnL3JmYy9yZmM0MjkxLnR4dFxuICBVUkkuaXA2X2V4cHJlc3Npb24gPSAvXlxccyooKChbMC05QS1GYS1mXXsxLDR9Oil7N30oWzAtOUEtRmEtZl17MSw0fXw6KSl8KChbMC05QS1GYS1mXXsxLDR9Oil7Nn0oOlswLTlBLUZhLWZdezEsNH18KCgyNVswLTVdfDJbMC00XVxcZHwxXFxkXFxkfFsxLTldP1xcZCkoXFwuKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKSl7M30pfDopKXwoKFswLTlBLUZhLWZdezEsNH06KXs1fSgoKDpbMC05QS1GYS1mXXsxLDR9KXsxLDJ9KXw6KCgyNVswLTVdfDJbMC00XVxcZHwxXFxkXFxkfFsxLTldP1xcZCkoXFwuKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKSl7M30pfDopKXwoKFswLTlBLUZhLWZdezEsNH06KXs0fSgoKDpbMC05QS1GYS1mXXsxLDR9KXsxLDN9KXwoKDpbMC05QS1GYS1mXXsxLDR9KT86KCgyNVswLTVdfDJbMC00XVxcZHwxXFxkXFxkfFsxLTldP1xcZCkoXFwuKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKSl7M30pKXw6KSl8KChbMC05QS1GYS1mXXsxLDR9Oil7M30oKCg6WzAtOUEtRmEtZl17MSw0fSl7MSw0fSl8KCg6WzAtOUEtRmEtZl17MSw0fSl7MCwyfTooKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKShcXC4oMjVbMC01XXwyWzAtNF1cXGR8MVxcZFxcZHxbMS05XT9cXGQpKXszfSkpfDopKXwoKFswLTlBLUZhLWZdezEsNH06KXsyfSgoKDpbMC05QS1GYS1mXXsxLDR9KXsxLDV9KXwoKDpbMC05QS1GYS1mXXsxLDR9KXswLDN9OigoMjVbMC01XXwyWzAtNF1cXGR8MVxcZFxcZHxbMS05XT9cXGQpKFxcLigyNVswLTVdfDJbMC00XVxcZHwxXFxkXFxkfFsxLTldP1xcZCkpezN9KSl8OikpfCgoWzAtOUEtRmEtZl17MSw0fTopezF9KCgoOlswLTlBLUZhLWZdezEsNH0pezEsNn0pfCgoOlswLTlBLUZhLWZdezEsNH0pezAsNH06KCgyNVswLTVdfDJbMC00XVxcZHwxXFxkXFxkfFsxLTldP1xcZCkoXFwuKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKSl7M30pKXw6KSl8KDooKCg6WzAtOUEtRmEtZl17MSw0fSl7MSw3fSl8KCg6WzAtOUEtRmEtZl17MSw0fSl7MCw1fTooKDI1WzAtNV18MlswLTRdXFxkfDFcXGRcXGR8WzEtOV0/XFxkKShcXC4oMjVbMC01XXwyWzAtNF1cXGR8MVxcZFxcZHxbMS05XT9cXGQpKXszfSkpfDopKSkoJS4rKT9cXHMqJC87XG4gIC8vIGV4cHJlc3Npb24gdXNlZCBpcyBcImdydWJlciByZXZpc2VkXCIgKEBncnViZXIgdjIpIGRldGVybWluZWQgdG8gYmUgdGhlXG4gIC8vIGJlc3Qgc29sdXRpb24gaW4gYSByZWdleC1nb2xmIHdlIGRpZCBhIGNvdXBsZSBvZiBhZ2VzIGFnbyBhdFxuICAvLyAqIGh0dHA6Ly9tYXRoaWFzYnluZW5zLmJlL2RlbW8vdXJsLXJlZ2V4XG4gIC8vICogaHR0cDovL3JvZG5leXJlaG0uZGUvdC91cmwtcmVnZXguaHRtbFxuICBVUkkuZmluZF91cmlfZXhwcmVzc2lvbiA9IC9cXGIoKD86W2Etel1bXFx3LV0rOig/OlxcL3sxLDN9fFthLXowLTklXSl8d3d3XFxkezAsM31bLl18W2EtejAtOS5cXC1dK1suXVthLXpdezIsNH1cXC8pKD86W15cXHMoKTw+XSt8XFwoKFteXFxzKCk8Pl0rfChcXChbXlxccygpPD5dK1xcKSkpKlxcKSkrKD86XFwoKFteXFxzKCk8Pl0rfChcXChbXlxccygpPD5dK1xcKSkpKlxcKXxbXlxcc2AhKClcXFtcXF17fTs6J1wiLiw8Pj/Cq8K74oCc4oCd4oCY4oCZXSkpL2lnO1xuICBVUkkuZmluZFVyaSA9IHtcbiAgICAvLyB2YWxpZCBcInNjaGVtZTovL1wiIG9yIFwid3d3LlwiXG4gICAgc3RhcnQ6IC9cXGIoPzooW2Etel1bYS16MC05ListXSo6XFwvXFwvKXx3d3dcXC4pL2dpLFxuICAgIC8vIGV2ZXJ5dGhpbmcgdXAgdG8gdGhlIG5leHQgd2hpdGVzcGFjZVxuICAgIGVuZDogL1tcXHNcXHJcXG5dfCQvLFxuICAgIC8vIHRyaW0gdHJhaWxpbmcgcHVuY3R1YXRpb24gY2FwdHVyZWQgYnkgZW5kIFJlZ0V4cFxuICAgIHRyaW06IC9bYCEoKVxcW1xcXXt9OzonXCIuLDw+P8KrwrvigJzigJ3igJ7igJjigJldKyQvXG4gIH07XG4gIC8vIGh0dHA6Ly93d3cuaWFuYS5vcmcvYXNzaWdubWVudHMvdXJpLXNjaGVtZXMuaHRtbFxuICAvLyBodHRwOi8vZW4ud2lraXBlZGlhLm9yZy93aWtpL0xpc3Rfb2ZfVENQX2FuZF9VRFBfcG9ydF9udW1iZXJzI1dlbGwta25vd25fcG9ydHNcbiAgVVJJLmRlZmF1bHRQb3J0cyA9IHtcbiAgICBodHRwOiAnODAnLFxuICAgIGh0dHBzOiAnNDQzJyxcbiAgICBmdHA6ICcyMScsXG4gICAgZ29waGVyOiAnNzAnLFxuICAgIHdzOiAnODAnLFxuICAgIHdzczogJzQ0MydcbiAgfTtcbiAgLy8gYWxsb3dlZCBob3N0bmFtZSBjaGFyYWN0ZXJzIGFjY29yZGluZyB0byBSRkMgMzk4NlxuICAvLyBBTFBIQSBESUdJVCBcIi1cIiBcIi5cIiBcIl9cIiBcIn5cIiBcIiFcIiBcIiRcIiBcIiZcIiBcIidcIiBcIihcIiBcIilcIiBcIipcIiBcIitcIiBcIixcIiBcIjtcIiBcIj1cIiAlZW5jb2RlZFxuICAvLyBJJ3ZlIG5ldmVyIHNlZW4gYSAobm9uLUlETikgaG9zdG5hbWUgb3RoZXIgdGhhbjogQUxQSEEgRElHSVQgLiAtXG4gIFVSSS5pbnZhbGlkX2hvc3RuYW1lX2NoYXJhY3RlcnMgPSAvW15hLXpBLVowLTlcXC4tXS87XG4gIC8vIG1hcCBET00gRWxlbWVudHMgdG8gdGhlaXIgVVJJIGF0dHJpYnV0ZVxuICBVUkkuZG9tQXR0cmlidXRlcyA9IHtcbiAgICAnYSc6ICdocmVmJyxcbiAgICAnYmxvY2txdW90ZSc6ICdjaXRlJyxcbiAgICAnbGluayc6ICdocmVmJyxcbiAgICAnYmFzZSc6ICdocmVmJyxcbiAgICAnc2NyaXB0JzogJ3NyYycsXG4gICAgJ2Zvcm0nOiAnYWN0aW9uJyxcbiAgICAnaW1nJzogJ3NyYycsXG4gICAgJ2FyZWEnOiAnaHJlZicsXG4gICAgJ2lmcmFtZSc6ICdzcmMnLFxuICAgICdlbWJlZCc6ICdzcmMnLFxuICAgICdzb3VyY2UnOiAnc3JjJyxcbiAgICAndHJhY2snOiAnc3JjJyxcbiAgICAnaW5wdXQnOiAnc3JjJywgLy8gYnV0IG9ubHkgaWYgdHlwZT1cImltYWdlXCJcbiAgICAnYXVkaW8nOiAnc3JjJyxcbiAgICAndmlkZW8nOiAnc3JjJ1xuICB9O1xuICBVUkkuZ2V0RG9tQXR0cmlidXRlID0gZnVuY3Rpb24obm9kZSkge1xuICAgIGlmICghbm9kZSB8fCAhbm9kZS5ub2RlTmFtZSkge1xuICAgICAgcmV0dXJuIHVuZGVmaW5lZDtcbiAgICB9XG5cbiAgICB2YXIgbm9kZU5hbWUgPSBub2RlLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCk7XG4gICAgLy8gPGlucHV0PiBzaG91bGQgb25seSBleHBvc2Ugc3JjIGZvciB0eXBlPVwiaW1hZ2VcIlxuICAgIGlmIChub2RlTmFtZSA9PT0gJ2lucHV0JyAmJiBub2RlLnR5cGUgIT09ICdpbWFnZScpIHtcbiAgICAgIHJldHVybiB1bmRlZmluZWQ7XG4gICAgfVxuXG4gICAgcmV0dXJuIFVSSS5kb21BdHRyaWJ1dGVzW25vZGVOYW1lXTtcbiAgfTtcblxuICBmdW5jdGlvbiBlc2NhcGVGb3JEdW1iRmlyZWZveDM2KHZhbHVlKSB7XG4gICAgLy8gaHR0cHM6Ly9naXRodWIuY29tL21lZGlhbGl6ZS9VUkkuanMvaXNzdWVzLzkxXG4gICAgcmV0dXJuIGVzY2FwZSh2YWx1ZSk7XG4gIH1cblxuICAvLyBlbmNvZGluZyAvIGRlY29kaW5nIGFjY29yZGluZyB0byBSRkMzOTg2XG4gIGZ1bmN0aW9uIHN0cmljdEVuY29kZVVSSUNvbXBvbmVudChzdHJpbmcpIHtcbiAgICAvLyBzZWUgaHR0cHM6Ly9kZXZlbG9wZXIubW96aWxsYS5vcmcvZW4tVVMvZG9jcy9KYXZhU2NyaXB0L1JlZmVyZW5jZS9HbG9iYWxfT2JqZWN0cy9lbmNvZGVVUklDb21wb25lbnRcbiAgICByZXR1cm4gZW5jb2RlVVJJQ29tcG9uZW50KHN0cmluZylcbiAgICAgIC5yZXBsYWNlKC9bIScoKSpdL2csIGVzY2FwZUZvckR1bWJGaXJlZm94MzYpXG4gICAgICAucmVwbGFjZSgvXFwqL2csICclMkEnKTtcbiAgfVxuICBVUkkuZW5jb2RlID0gc3RyaWN0RW5jb2RlVVJJQ29tcG9uZW50O1xuICBVUkkuZGVjb2RlID0gZGVjb2RlVVJJQ29tcG9uZW50O1xuICBVUkkuaXNvODg1OSA9IGZ1bmN0aW9uKCkge1xuICAgIFVSSS5lbmNvZGUgPSBlc2NhcGU7XG4gICAgVVJJLmRlY29kZSA9IHVuZXNjYXBlO1xuICB9O1xuICBVUkkudW5pY29kZSA9IGZ1bmN0aW9uKCkge1xuICAgIFVSSS5lbmNvZGUgPSBzdHJpY3RFbmNvZGVVUklDb21wb25lbnQ7XG4gICAgVVJJLmRlY29kZSA9IGRlY29kZVVSSUNvbXBvbmVudDtcbiAgfTtcbiAgVVJJLmNoYXJhY3RlcnMgPSB7XG4gICAgcGF0aG5hbWU6IHtcbiAgICAgIGVuY29kZToge1xuICAgICAgICAvLyBSRkMzOTg2IDIuMTogRm9yIGNvbnNpc3RlbmN5LCBVUkkgcHJvZHVjZXJzIGFuZCBub3JtYWxpemVycyBzaG91bGRcbiAgICAgICAgLy8gdXNlIHVwcGVyY2FzZSBoZXhhZGVjaW1hbCBkaWdpdHMgZm9yIGFsbCBwZXJjZW50LWVuY29kaW5ncy5cbiAgICAgICAgZXhwcmVzc2lvbjogLyUoMjR8MjZ8MkJ8MkN8M0J8M0R8M0F8NDApL2lnLFxuICAgICAgICBtYXA6IHtcbiAgICAgICAgICAvLyAtLl9+IScoKSpcbiAgICAgICAgICAnJTI0JzogJyQnLFxuICAgICAgICAgICclMjYnOiAnJicsXG4gICAgICAgICAgJyUyQic6ICcrJyxcbiAgICAgICAgICAnJTJDJzogJywnLFxuICAgICAgICAgICclM0InOiAnOycsXG4gICAgICAgICAgJyUzRCc6ICc9JyxcbiAgICAgICAgICAnJTNBJzogJzonLFxuICAgICAgICAgICclNDAnOiAnQCdcbiAgICAgICAgfVxuICAgICAgfSxcbiAgICAgIGRlY29kZToge1xuICAgICAgICBleHByZXNzaW9uOiAvW1xcL1xcPyNdL2csXG4gICAgICAgIG1hcDoge1xuICAgICAgICAgICcvJzogJyUyRicsXG4gICAgICAgICAgJz8nOiAnJTNGJyxcbiAgICAgICAgICAnIyc6ICclMjMnXG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9LFxuICAgIHJlc2VydmVkOiB7XG4gICAgICBlbmNvZGU6IHtcbiAgICAgICAgLy8gUkZDMzk4NiAyLjE6IEZvciBjb25zaXN0ZW5jeSwgVVJJIHByb2R1Y2VycyBhbmQgbm9ybWFsaXplcnMgc2hvdWxkXG4gICAgICAgIC8vIHVzZSB1cHBlcmNhc2UgaGV4YWRlY2ltYWwgZGlnaXRzIGZvciBhbGwgcGVyY2VudC1lbmNvZGluZ3MuXG4gICAgICAgIGV4cHJlc3Npb246IC8lKDIxfDIzfDI0fDI2fDI3fDI4fDI5fDJBfDJCfDJDfDJGfDNBfDNCfDNEfDNGfDQwfDVCfDVEKS9pZyxcbiAgICAgICAgbWFwOiB7XG4gICAgICAgICAgLy8gZ2VuLWRlbGltc1xuICAgICAgICAgICclM0EnOiAnOicsXG4gICAgICAgICAgJyUyRic6ICcvJyxcbiAgICAgICAgICAnJTNGJzogJz8nLFxuICAgICAgICAgICclMjMnOiAnIycsXG4gICAgICAgICAgJyU1Qic6ICdbJyxcbiAgICAgICAgICAnJTVEJzogJ10nLFxuICAgICAgICAgICclNDAnOiAnQCcsXG4gICAgICAgICAgLy8gc3ViLWRlbGltc1xuICAgICAgICAgICclMjEnOiAnIScsXG4gICAgICAgICAgJyUyNCc6ICckJyxcbiAgICAgICAgICAnJTI2JzogJyYnLFxuICAgICAgICAgICclMjcnOiAnXFwnJyxcbiAgICAgICAgICAnJTI4JzogJygnLFxuICAgICAgICAgICclMjknOiAnKScsXG4gICAgICAgICAgJyUyQSc6ICcqJyxcbiAgICAgICAgICAnJTJCJzogJysnLFxuICAgICAgICAgICclMkMnOiAnLCcsXG4gICAgICAgICAgJyUzQic6ICc7JyxcbiAgICAgICAgICAnJTNEJzogJz0nXG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9LFxuICAgIHVybnBhdGg6IHtcbiAgICAgIC8vIFRoZSBjaGFyYWN0ZXJzIHVuZGVyIGBlbmNvZGVgIGFyZSB0aGUgY2hhcmFjdGVycyBjYWxsZWQgb3V0IGJ5IFJGQyAyMTQxIGFzIGJlaW5nIGFjY2VwdGFibGVcbiAgICAgIC8vIGZvciB1c2FnZSBpbiBhIFVSTi4gUkZDMjE0MSBhbHNvIGNhbGxzIG91dCBcIi1cIiwgXCIuXCIsIGFuZCBcIl9cIiBhcyBhY2NlcHRhYmxlIGNoYXJhY3RlcnMsIGJ1dFxuICAgICAgLy8gdGhlc2UgYXJlbid0IGVuY29kZWQgYnkgZW5jb2RlVVJJQ29tcG9uZW50LCBzbyB3ZSBkb24ndCBoYXZlIHRvIGNhbGwgdGhlbSBvdXQgaGVyZS4gQWxzb1xuICAgICAgLy8gbm90ZSB0aGF0IHRoZSBjb2xvbiBjaGFyYWN0ZXIgaXMgbm90IGZlYXR1cmVkIGluIHRoZSBlbmNvZGluZyBtYXA7IHRoaXMgaXMgYmVjYXVzZSBVUkkuanNcbiAgICAgIC8vIGdpdmVzIHRoZSBjb2xvbnMgaW4gVVJOcyBzZW1hbnRpYyBtZWFuaW5nIGFzIHRoZSBkZWxpbWl0ZXJzIG9mIHBhdGggc2VnZW1lbnRzLCBhbmQgc28gaXRcbiAgICAgIC8vIHNob3VsZCBub3QgYXBwZWFyIHVuZW5jb2RlZCBpbiBhIHNlZ21lbnQgaXRzZWxmLlxuICAgICAgLy8gU2VlIGFsc28gdGhlIG5vdGUgYWJvdmUgYWJvdXQgUkZDMzk4NiBhbmQgY2FwaXRhbGFsaXplZCBoZXggZGlnaXRzLlxuICAgICAgZW5jb2RlOiB7XG4gICAgICAgIGV4cHJlc3Npb246IC8lKDIxfDI0fDI3fDI4fDI5fDJBfDJCfDJDfDNCfDNEfDQwKS9pZyxcbiAgICAgICAgbWFwOiB7XG4gICAgICAgICAgJyUyMSc6ICchJyxcbiAgICAgICAgICAnJTI0JzogJyQnLFxuICAgICAgICAgICclMjcnOiAnXFwnJyxcbiAgICAgICAgICAnJTI4JzogJygnLFxuICAgICAgICAgICclMjknOiAnKScsXG4gICAgICAgICAgJyUyQSc6ICcqJyxcbiAgICAgICAgICAnJTJCJzogJysnLFxuICAgICAgICAgICclMkMnOiAnLCcsXG4gICAgICAgICAgJyUzQic6ICc7JyxcbiAgICAgICAgICAnJTNEJzogJz0nLFxuICAgICAgICAgICclNDAnOiAnQCdcbiAgICAgICAgfVxuICAgICAgfSxcbiAgICAgIC8vIFRoZXNlIGNoYXJhY3RlcnMgYXJlIHRoZSBjaGFyYWN0ZXJzIGNhbGxlZCBvdXQgYnkgUkZDMjE0MSBhcyBcInJlc2VydmVkXCIgY2hhcmFjdGVycyB0aGF0XG4gICAgICAvLyBzaG91bGQgbmV2ZXIgYXBwZWFyIGluIGEgVVJOLCBwbHVzIHRoZSBjb2xvbiBjaGFyYWN0ZXIgKHNlZSBub3RlIGFib3ZlKS5cbiAgICAgIGRlY29kZToge1xuICAgICAgICBleHByZXNzaW9uOiAvW1xcL1xcPyM6XS9nLFxuICAgICAgICBtYXA6IHtcbiAgICAgICAgICAnLyc6ICclMkYnLFxuICAgICAgICAgICc/JzogJyUzRicsXG4gICAgICAgICAgJyMnOiAnJTIzJyxcbiAgICAgICAgICAnOic6ICclM0EnXG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gIH07XG4gIFVSSS5lbmNvZGVRdWVyeSA9IGZ1bmN0aW9uKHN0cmluZywgZXNjYXBlUXVlcnlTcGFjZSkge1xuICAgIHZhciBlc2NhcGVkID0gVVJJLmVuY29kZShzdHJpbmcgKyAnJyk7XG4gICAgaWYgKGVzY2FwZVF1ZXJ5U3BhY2UgPT09IHVuZGVmaW5lZCkge1xuICAgICAgZXNjYXBlUXVlcnlTcGFjZSA9IFVSSS5lc2NhcGVRdWVyeVNwYWNlO1xuICAgIH1cblxuICAgIHJldHVybiBlc2NhcGVRdWVyeVNwYWNlID8gZXNjYXBlZC5yZXBsYWNlKC8lMjAvZywgJysnKSA6IGVzY2FwZWQ7XG4gIH07XG4gIFVSSS5kZWNvZGVRdWVyeSA9IGZ1bmN0aW9uKHN0cmluZywgZXNjYXBlUXVlcnlTcGFjZSkge1xuICAgIHN0cmluZyArPSAnJztcbiAgICBpZiAoZXNjYXBlUXVlcnlTcGFjZSA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICBlc2NhcGVRdWVyeVNwYWNlID0gVVJJLmVzY2FwZVF1ZXJ5U3BhY2U7XG4gICAgfVxuXG4gICAgdHJ5IHtcbiAgICAgIHJldHVybiBVUkkuZGVjb2RlKGVzY2FwZVF1ZXJ5U3BhY2UgPyBzdHJpbmcucmVwbGFjZSgvXFwrL2csICclMjAnKSA6IHN0cmluZyk7XG4gICAgfSBjYXRjaChlKSB7XG4gICAgICAvLyB3ZSdyZSBub3QgZ29pbmcgdG8gbWVzcyB3aXRoIHdlaXJkIGVuY29kaW5ncyxcbiAgICAgIC8vIGdpdmUgdXAgYW5kIHJldHVybiB0aGUgdW5kZWNvZGVkIG9yaWdpbmFsIHN0cmluZ1xuICAgICAgLy8gc2VlIGh0dHBzOi8vZ2l0aHViLmNvbS9tZWRpYWxpemUvVVJJLmpzL2lzc3Vlcy84N1xuICAgICAgLy8gc2VlIGh0dHBzOi8vZ2l0aHViLmNvbS9tZWRpYWxpemUvVVJJLmpzL2lzc3Vlcy85MlxuICAgICAgcmV0dXJuIHN0cmluZztcbiAgICB9XG4gIH07XG4gIC8vIGdlbmVyYXRlIGVuY29kZS9kZWNvZGUgcGF0aCBmdW5jdGlvbnNcbiAgdmFyIF9wYXJ0cyA9IHsnZW5jb2RlJzonZW5jb2RlJywgJ2RlY29kZSc6J2RlY29kZSd9O1xuICB2YXIgX3BhcnQ7XG4gIHZhciBnZW5lcmF0ZUFjY2Vzc29yID0gZnVuY3Rpb24oX2dyb3VwLCBfcGFydCkge1xuICAgIHJldHVybiBmdW5jdGlvbihzdHJpbmcpIHtcbiAgICAgIHRyeSB7XG4gICAgICAgIHJldHVybiBVUklbX3BhcnRdKHN0cmluZyArICcnKS5yZXBsYWNlKFVSSS5jaGFyYWN0ZXJzW19ncm91cF1bX3BhcnRdLmV4cHJlc3Npb24sIGZ1bmN0aW9uKGMpIHtcbiAgICAgICAgICByZXR1cm4gVVJJLmNoYXJhY3RlcnNbX2dyb3VwXVtfcGFydF0ubWFwW2NdO1xuICAgICAgICB9KTtcbiAgICAgIH0gY2F0Y2ggKGUpIHtcbiAgICAgICAgLy8gd2UncmUgbm90IGdvaW5nIHRvIG1lc3Mgd2l0aCB3ZWlyZCBlbmNvZGluZ3MsXG4gICAgICAgIC8vIGdpdmUgdXAgYW5kIHJldHVybiB0aGUgdW5kZWNvZGVkIG9yaWdpbmFsIHN0cmluZ1xuICAgICAgICAvLyBzZWUgaHR0cHM6Ly9naXRodWIuY29tL21lZGlhbGl6ZS9VUkkuanMvaXNzdWVzLzg3XG4gICAgICAgIC8vIHNlZSBodHRwczovL2dpdGh1Yi5jb20vbWVkaWFsaXplL1VSSS5qcy9pc3N1ZXMvOTJcbiAgICAgICAgcmV0dXJuIHN0cmluZztcbiAgICAgIH1cbiAgICB9O1xuICB9O1xuXG4gIGZvciAoX3BhcnQgaW4gX3BhcnRzKSB7XG4gICAgVVJJW19wYXJ0ICsgJ1BhdGhTZWdtZW50J10gPSBnZW5lcmF0ZUFjY2Vzc29yKCdwYXRobmFtZScsIF9wYXJ0c1tfcGFydF0pO1xuICAgIFVSSVtfcGFydCArICdVcm5QYXRoU2VnbWVudCddID0gZ2VuZXJhdGVBY2Nlc3NvcigndXJucGF0aCcsIF9wYXJ0c1tfcGFydF0pO1xuICB9XG5cbiAgdmFyIGdlbmVyYXRlU2VnbWVudGVkUGF0aEZ1bmN0aW9uID0gZnVuY3Rpb24oX3NlcCwgX2NvZGluZ0Z1bmNOYW1lLCBfaW5uZXJDb2RpbmdGdW5jTmFtZSkge1xuICAgIHJldHVybiBmdW5jdGlvbihzdHJpbmcpIHtcbiAgICAgIC8vIFdoeSBwYXNzIGluIG5hbWVzIG9mIGZ1bmN0aW9ucywgcmF0aGVyIHRoYW4gdGhlIGZ1bmN0aW9uIG9iamVjdHMgdGhlbXNlbHZlcz8gVGhlXG4gICAgICAvLyBkZWZpbml0aW9ucyBvZiBzb21lIGZ1bmN0aW9ucyAoYnV0IGluIHBhcnRpY3VsYXIsIFVSSS5kZWNvZGUpIHdpbGwgb2NjYXNpb25hbGx5IGNoYW5nZSBkdWVcbiAgICAgIC8vIHRvIFVSSS5qcyBoYXZpbmcgSVNPODg1OSBhbmQgVW5pY29kZSBtb2Rlcy4gUGFzc2luZyBpbiB0aGUgbmFtZSBhbmQgZ2V0dGluZyBpdCB3aWxsIGVuc3VyZVxuICAgICAgLy8gdGhhdCB0aGUgZnVuY3Rpb25zIHdlIHVzZSBoZXJlIGFyZSBcImZyZXNoXCIuXG4gICAgICB2YXIgYWN0dWFsQ29kaW5nRnVuYztcbiAgICAgIGlmICghX2lubmVyQ29kaW5nRnVuY05hbWUpIHtcbiAgICAgICAgYWN0dWFsQ29kaW5nRnVuYyA9IFVSSVtfY29kaW5nRnVuY05hbWVdO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgYWN0dWFsQ29kaW5nRnVuYyA9IGZ1bmN0aW9uKHN0cmluZykge1xuICAgICAgICAgIHJldHVybiBVUklbX2NvZGluZ0Z1bmNOYW1lXShVUklbX2lubmVyQ29kaW5nRnVuY05hbWVdKHN0cmluZykpO1xuICAgICAgICB9O1xuICAgICAgfVxuXG4gICAgICB2YXIgc2VnbWVudHMgPSAoc3RyaW5nICsgJycpLnNwbGl0KF9zZXApO1xuXG4gICAgICBmb3IgKHZhciBpID0gMCwgbGVuZ3RoID0gc2VnbWVudHMubGVuZ3RoOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgICAgc2VnbWVudHNbaV0gPSBhY3R1YWxDb2RpbmdGdW5jKHNlZ21lbnRzW2ldKTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIHNlZ21lbnRzLmpvaW4oX3NlcCk7XG4gICAgfTtcbiAgfTtcblxuICAvLyBUaGlzIHRha2VzIHBsYWNlIG91dHNpZGUgdGhlIGFib3ZlIGxvb3AgYmVjYXVzZSB3ZSBkb24ndCB3YW50LCBlLmcuLCBlbmNvZGVVcm5QYXRoIGZ1bmN0aW9ucy5cbiAgVVJJLmRlY29kZVBhdGggPSBnZW5lcmF0ZVNlZ21lbnRlZFBhdGhGdW5jdGlvbignLycsICdkZWNvZGVQYXRoU2VnbWVudCcpO1xuICBVUkkuZGVjb2RlVXJuUGF0aCA9IGdlbmVyYXRlU2VnbWVudGVkUGF0aEZ1bmN0aW9uKCc6JywgJ2RlY29kZVVyblBhdGhTZWdtZW50Jyk7XG4gIFVSSS5yZWNvZGVQYXRoID0gZ2VuZXJhdGVTZWdtZW50ZWRQYXRoRnVuY3Rpb24oJy8nLCAnZW5jb2RlUGF0aFNlZ21lbnQnLCAnZGVjb2RlJyk7XG4gIFVSSS5yZWNvZGVVcm5QYXRoID0gZ2VuZXJhdGVTZWdtZW50ZWRQYXRoRnVuY3Rpb24oJzonLCAnZW5jb2RlVXJuUGF0aFNlZ21lbnQnLCAnZGVjb2RlJyk7XG5cbiAgVVJJLmVuY29kZVJlc2VydmVkID0gZ2VuZXJhdGVBY2Nlc3NvcigncmVzZXJ2ZWQnLCAnZW5jb2RlJyk7XG5cbiAgVVJJLnBhcnNlID0gZnVuY3Rpb24oc3RyaW5nLCBwYXJ0cykge1xuICAgIHZhciBwb3M7XG4gICAgaWYgKCFwYXJ0cykge1xuICAgICAgcGFydHMgPSB7fTtcbiAgICB9XG4gICAgLy8gW3Byb3RvY29sXCI6Ly9cIlt1c2VybmFtZVtcIjpcInBhc3N3b3JkXVwiQFwiXWhvc3RuYW1lW1wiOlwicG9ydF1cIi9cIj9dW3BhdGhdW1wiP1wicXVlcnlzdHJpbmddW1wiI1wiZnJhZ21lbnRdXG5cbiAgICAvLyBleHRyYWN0IGZyYWdtZW50XG4gICAgcG9zID0gc3RyaW5nLmluZGV4T2YoJyMnKTtcbiAgICBpZiAocG9zID4gLTEpIHtcbiAgICAgIC8vIGVzY2FwaW5nP1xuICAgICAgcGFydHMuZnJhZ21lbnQgPSBzdHJpbmcuc3Vic3RyaW5nKHBvcyArIDEpIHx8IG51bGw7XG4gICAgICBzdHJpbmcgPSBzdHJpbmcuc3Vic3RyaW5nKDAsIHBvcyk7XG4gICAgfVxuXG4gICAgLy8gZXh0cmFjdCBxdWVyeVxuICAgIHBvcyA9IHN0cmluZy5pbmRleE9mKCc/Jyk7XG4gICAgaWYgKHBvcyA+IC0xKSB7XG4gICAgICAvLyBlc2NhcGluZz9cbiAgICAgIHBhcnRzLnF1ZXJ5ID0gc3RyaW5nLnN1YnN0cmluZyhwb3MgKyAxKSB8fCBudWxsO1xuICAgICAgc3RyaW5nID0gc3RyaW5nLnN1YnN0cmluZygwLCBwb3MpO1xuICAgIH1cblxuICAgIC8vIGV4dHJhY3QgcHJvdG9jb2xcbiAgICBpZiAoc3RyaW5nLnN1YnN0cmluZygwLCAyKSA9PT0gJy8vJykge1xuICAgICAgLy8gcmVsYXRpdmUtc2NoZW1lXG4gICAgICBwYXJ0cy5wcm90b2NvbCA9IG51bGw7XG4gICAgICBzdHJpbmcgPSBzdHJpbmcuc3Vic3RyaW5nKDIpO1xuICAgICAgLy8gZXh0cmFjdCBcInVzZXI6cGFzc0Bob3N0OnBvcnRcIlxuICAgICAgc3RyaW5nID0gVVJJLnBhcnNlQXV0aG9yaXR5KHN0cmluZywgcGFydHMpO1xuICAgIH0gZWxzZSB7XG4gICAgICBwb3MgPSBzdHJpbmcuaW5kZXhPZignOicpO1xuICAgICAgaWYgKHBvcyA+IC0xKSB7XG4gICAgICAgIHBhcnRzLnByb3RvY29sID0gc3RyaW5nLnN1YnN0cmluZygwLCBwb3MpIHx8IG51bGw7XG4gICAgICAgIGlmIChwYXJ0cy5wcm90b2NvbCAmJiAhcGFydHMucHJvdG9jb2wubWF0Y2goVVJJLnByb3RvY29sX2V4cHJlc3Npb24pKSB7XG4gICAgICAgICAgLy8gOiBtYXkgYmUgd2l0aGluIHRoZSBwYXRoXG4gICAgICAgICAgcGFydHMucHJvdG9jb2wgPSB1bmRlZmluZWQ7XG4gICAgICAgIH0gZWxzZSBpZiAoc3RyaW5nLnN1YnN0cmluZyhwb3MgKyAxLCBwb3MgKyAzKSA9PT0gJy8vJykge1xuICAgICAgICAgIHN0cmluZyA9IHN0cmluZy5zdWJzdHJpbmcocG9zICsgMyk7XG5cbiAgICAgICAgICAvLyBleHRyYWN0IFwidXNlcjpwYXNzQGhvc3Q6cG9ydFwiXG4gICAgICAgICAgc3RyaW5nID0gVVJJLnBhcnNlQXV0aG9yaXR5KHN0cmluZywgcGFydHMpO1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHN0cmluZyA9IHN0cmluZy5zdWJzdHJpbmcocG9zICsgMSk7XG4gICAgICAgICAgcGFydHMudXJuID0gdHJ1ZTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cblxuICAgIC8vIHdoYXQncyBsZWZ0IG11c3QgYmUgdGhlIHBhdGhcbiAgICBwYXJ0cy5wYXRoID0gc3RyaW5nO1xuXG4gICAgLy8gYW5kIHdlJ3JlIGRvbmVcbiAgICByZXR1cm4gcGFydHM7XG4gIH07XG4gIFVSSS5wYXJzZUhvc3QgPSBmdW5jdGlvbihzdHJpbmcsIHBhcnRzKSB7XG4gICAgLy8gQ29weSBjaHJvbWUsIElFLCBvcGVyYSBiYWNrc2xhc2gtaGFuZGxpbmcgYmVoYXZpb3IuXG4gICAgLy8gQmFjayBzbGFzaGVzIGJlZm9yZSB0aGUgcXVlcnkgc3RyaW5nIGdldCBjb252ZXJ0ZWQgdG8gZm9yd2FyZCBzbGFzaGVzXG4gICAgLy8gU2VlOiBodHRwczovL2dpdGh1Yi5jb20vam95ZW50L25vZGUvYmxvYi8zODZmZDI0ZjQ5YjBlOWQxYThhMDc2NTkyYTQwNDE2OGZhZWVjYzM0L2xpYi91cmwuanMjTDExNS1MMTI0XG4gICAgLy8gU2VlOiBodHRwczovL2NvZGUuZ29vZ2xlLmNvbS9wL2Nocm9taXVtL2lzc3Vlcy9kZXRhaWw/aWQ9MjU5MTZcbiAgICAvLyBodHRwczovL2dpdGh1Yi5jb20vbWVkaWFsaXplL1VSSS5qcy9wdWxsLzIzM1xuICAgIHN0cmluZyA9IHN0cmluZy5yZXBsYWNlKC9cXFxcL2csICcvJyk7XG5cbiAgICAvLyBleHRyYWN0IGhvc3Q6cG9ydFxuICAgIHZhciBwb3MgPSBzdHJpbmcuaW5kZXhPZignLycpO1xuICAgIHZhciBicmFja2V0UG9zO1xuICAgIHZhciB0O1xuXG4gICAgaWYgKHBvcyA9PT0gLTEpIHtcbiAgICAgIHBvcyA9IHN0cmluZy5sZW5ndGg7XG4gICAgfVxuXG4gICAgaWYgKHN0cmluZy5jaGFyQXQoMCkgPT09ICdbJykge1xuICAgICAgLy8gSVB2NiBob3N0IC0gaHR0cDovL3Rvb2xzLmlldGYub3JnL2h0bWwvZHJhZnQtaWV0Zi02bWFuLXRleHQtYWRkci1yZXByZXNlbnRhdGlvbi0wNCNzZWN0aW9uLTZcbiAgICAgIC8vIEkgY2xhaW0gbW9zdCBjbGllbnQgc29mdHdhcmUgYnJlYWtzIG9uIElQdjYgYW55d2F5cy4gVG8gc2ltcGxpZnkgdGhpbmdzLCBVUkkgb25seSBhY2NlcHRzXG4gICAgICAvLyBJUHY2K3BvcnQgaW4gdGhlIGZvcm1hdCBbMjAwMTpkYjg6OjFdOjgwIChmb3IgdGhlIHRpbWUgYmVpbmcpXG4gICAgICBicmFja2V0UG9zID0gc3RyaW5nLmluZGV4T2YoJ10nKTtcbiAgICAgIHBhcnRzLmhvc3RuYW1lID0gc3RyaW5nLnN1YnN0cmluZygxLCBicmFja2V0UG9zKSB8fCBudWxsO1xuICAgICAgcGFydHMucG9ydCA9IHN0cmluZy5zdWJzdHJpbmcoYnJhY2tldFBvcyArIDIsIHBvcykgfHwgbnVsbDtcbiAgICAgIGlmIChwYXJ0cy5wb3J0ID09PSAnLycpIHtcbiAgICAgICAgcGFydHMucG9ydCA9IG51bGw7XG4gICAgICB9XG4gICAgfSBlbHNlIHtcbiAgICAgIHZhciBmaXJzdENvbG9uID0gc3RyaW5nLmluZGV4T2YoJzonKTtcbiAgICAgIHZhciBmaXJzdFNsYXNoID0gc3RyaW5nLmluZGV4T2YoJy8nKTtcbiAgICAgIHZhciBuZXh0Q29sb24gPSBzdHJpbmcuaW5kZXhPZignOicsIGZpcnN0Q29sb24gKyAxKTtcbiAgICAgIGlmIChuZXh0Q29sb24gIT09IC0xICYmIChmaXJzdFNsYXNoID09PSAtMSB8fCBuZXh0Q29sb24gPCBmaXJzdFNsYXNoKSkge1xuICAgICAgICAvLyBJUHY2IGhvc3QgY29udGFpbnMgbXVsdGlwbGUgY29sb25zIC0gYnV0IG5vIHBvcnRcbiAgICAgICAgLy8gdGhpcyBub3RhdGlvbiBpcyBhY3R1YWxseSBub3QgYWxsb3dlZCBieSBSRkMgMzk4NiwgYnV0IHdlJ3JlIGEgbGliZXJhbCBwYXJzZXJcbiAgICAgICAgcGFydHMuaG9zdG5hbWUgPSBzdHJpbmcuc3Vic3RyaW5nKDAsIHBvcykgfHwgbnVsbDtcbiAgICAgICAgcGFydHMucG9ydCA9IG51bGw7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0ID0gc3RyaW5nLnN1YnN0cmluZygwLCBwb3MpLnNwbGl0KCc6Jyk7XG4gICAgICAgIHBhcnRzLmhvc3RuYW1lID0gdFswXSB8fCBudWxsO1xuICAgICAgICBwYXJ0cy5wb3J0ID0gdFsxXSB8fCBudWxsO1xuICAgICAgfVxuICAgIH1cblxuICAgIGlmIChwYXJ0cy5ob3N0bmFtZSAmJiBzdHJpbmcuc3Vic3RyaW5nKHBvcykuY2hhckF0KDApICE9PSAnLycpIHtcbiAgICAgIHBvcysrO1xuICAgICAgc3RyaW5nID0gJy8nICsgc3RyaW5nO1xuICAgIH1cblxuICAgIHJldHVybiBzdHJpbmcuc3Vic3RyaW5nKHBvcykgfHwgJy8nO1xuICB9O1xuICBVUkkucGFyc2VBdXRob3JpdHkgPSBmdW5jdGlvbihzdHJpbmcsIHBhcnRzKSB7XG4gICAgc3RyaW5nID0gVVJJLnBhcnNlVXNlcmluZm8oc3RyaW5nLCBwYXJ0cyk7XG4gICAgcmV0dXJuIFVSSS5wYXJzZUhvc3Qoc3RyaW5nLCBwYXJ0cyk7XG4gIH07XG4gIFVSSS5wYXJzZVVzZXJpbmZvID0gZnVuY3Rpb24oc3RyaW5nLCBwYXJ0cykge1xuICAgIC8vIGV4dHJhY3QgdXNlcm5hbWU6cGFzc3dvcmRcbiAgICB2YXIgZmlyc3RTbGFzaCA9IHN0cmluZy5pbmRleE9mKCcvJyk7XG4gICAgdmFyIHBvcyA9IHN0cmluZy5sYXN0SW5kZXhPZignQCcsIGZpcnN0U2xhc2ggPiAtMSA/IGZpcnN0U2xhc2ggOiBzdHJpbmcubGVuZ3RoIC0gMSk7XG4gICAgdmFyIHQ7XG5cbiAgICAvLyBhdXRob3JpdHlAIG11c3QgY29tZSBiZWZvcmUgL3BhdGhcbiAgICBpZiAocG9zID4gLTEgJiYgKGZpcnN0U2xhc2ggPT09IC0xIHx8IHBvcyA8IGZpcnN0U2xhc2gpKSB7XG4gICAgICB0ID0gc3RyaW5nLnN1YnN0cmluZygwLCBwb3MpLnNwbGl0KCc6Jyk7XG4gICAgICBwYXJ0cy51c2VybmFtZSA9IHRbMF0gPyBVUkkuZGVjb2RlKHRbMF0pIDogbnVsbDtcbiAgICAgIHQuc2hpZnQoKTtcbiAgICAgIHBhcnRzLnBhc3N3b3JkID0gdFswXSA/IFVSSS5kZWNvZGUodC5qb2luKCc6JykpIDogbnVsbDtcbiAgICAgIHN0cmluZyA9IHN0cmluZy5zdWJzdHJpbmcocG9zICsgMSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIHBhcnRzLnVzZXJuYW1lID0gbnVsbDtcbiAgICAgIHBhcnRzLnBhc3N3b3JkID0gbnVsbDtcbiAgICB9XG5cbiAgICByZXR1cm4gc3RyaW5nO1xuICB9O1xuICBVUkkucGFyc2VRdWVyeSA9IGZ1bmN0aW9uKHN0cmluZywgZXNjYXBlUXVlcnlTcGFjZSkge1xuICAgIGlmICghc3RyaW5nKSB7XG4gICAgICByZXR1cm4ge307XG4gICAgfVxuXG4gICAgLy8gdGhyb3cgb3V0IHRoZSBmdW5reSBidXNpbmVzcyAtIFwiP1wiW25hbWVcIj1cInZhbHVlXCImXCJdK1xuICAgIHN0cmluZyA9IHN0cmluZy5yZXBsYWNlKC8mKy9nLCAnJicpLnJlcGxhY2UoL15cXD8qJip8JiskL2csICcnKTtcblxuICAgIGlmICghc3RyaW5nKSB7XG4gICAgICByZXR1cm4ge307XG4gICAgfVxuXG4gICAgdmFyIGl0ZW1zID0ge307XG4gICAgdmFyIHNwbGl0cyA9IHN0cmluZy5zcGxpdCgnJicpO1xuICAgIHZhciBsZW5ndGggPSBzcGxpdHMubGVuZ3RoO1xuICAgIHZhciB2LCBuYW1lLCB2YWx1ZTtcblxuICAgIGZvciAodmFyIGkgPSAwOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgIHYgPSBzcGxpdHNbaV0uc3BsaXQoJz0nKTtcbiAgICAgIG5hbWUgPSBVUkkuZGVjb2RlUXVlcnkodi5zaGlmdCgpLCBlc2NhcGVRdWVyeVNwYWNlKTtcbiAgICAgIC8vIG5vIFwiPVwiIGlzIG51bGwgYWNjb3JkaW5nIHRvIGh0dHA6Ly9kdmNzLnczLm9yZy9oZy91cmwvcmF3LWZpbGUvdGlwL092ZXJ2aWV3Lmh0bWwjY29sbGVjdC11cmwtcGFyYW1ldGVyc1xuICAgICAgdmFsdWUgPSB2Lmxlbmd0aCA/IFVSSS5kZWNvZGVRdWVyeSh2LmpvaW4oJz0nKSwgZXNjYXBlUXVlcnlTcGFjZSkgOiBudWxsO1xuXG4gICAgICBpZiAoaGFzT3duLmNhbGwoaXRlbXMsIG5hbWUpKSB7XG4gICAgICAgIGlmICh0eXBlb2YgaXRlbXNbbmFtZV0gPT09ICdzdHJpbmcnIHx8IGl0ZW1zW25hbWVdID09PSBudWxsKSB7XG4gICAgICAgICAgaXRlbXNbbmFtZV0gPSBbaXRlbXNbbmFtZV1dO1xuICAgICAgICB9XG5cbiAgICAgICAgaXRlbXNbbmFtZV0ucHVzaCh2YWx1ZSk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBpdGVtc1tuYW1lXSA9IHZhbHVlO1xuICAgICAgfVxuICAgIH1cblxuICAgIHJldHVybiBpdGVtcztcbiAgfTtcblxuICBVUkkuYnVpbGQgPSBmdW5jdGlvbihwYXJ0cykge1xuICAgIHZhciB0ID0gJyc7XG5cbiAgICBpZiAocGFydHMucHJvdG9jb2wpIHtcbiAgICAgIHQgKz0gcGFydHMucHJvdG9jb2wgKyAnOic7XG4gICAgfVxuXG4gICAgaWYgKCFwYXJ0cy51cm4gJiYgKHQgfHwgcGFydHMuaG9zdG5hbWUpKSB7XG4gICAgICB0ICs9ICcvLyc7XG4gICAgfVxuXG4gICAgdCArPSAoVVJJLmJ1aWxkQXV0aG9yaXR5KHBhcnRzKSB8fCAnJyk7XG5cbiAgICBpZiAodHlwZW9mIHBhcnRzLnBhdGggPT09ICdzdHJpbmcnKSB7XG4gICAgICBpZiAocGFydHMucGF0aC5jaGFyQXQoMCkgIT09ICcvJyAmJiB0eXBlb2YgcGFydHMuaG9zdG5hbWUgPT09ICdzdHJpbmcnKSB7XG4gICAgICAgIHQgKz0gJy8nO1xuICAgICAgfVxuXG4gICAgICB0ICs9IHBhcnRzLnBhdGg7XG4gICAgfVxuXG4gICAgaWYgKHR5cGVvZiBwYXJ0cy5xdWVyeSA9PT0gJ3N0cmluZycgJiYgcGFydHMucXVlcnkpIHtcbiAgICAgIHQgKz0gJz8nICsgcGFydHMucXVlcnk7XG4gICAgfVxuXG4gICAgaWYgKHR5cGVvZiBwYXJ0cy5mcmFnbWVudCA9PT0gJ3N0cmluZycgJiYgcGFydHMuZnJhZ21lbnQpIHtcbiAgICAgIHQgKz0gJyMnICsgcGFydHMuZnJhZ21lbnQ7XG4gICAgfVxuICAgIHJldHVybiB0O1xuICB9O1xuICBVUkkuYnVpbGRIb3N0ID0gZnVuY3Rpb24ocGFydHMpIHtcbiAgICB2YXIgdCA9ICcnO1xuXG4gICAgaWYgKCFwYXJ0cy5ob3N0bmFtZSkge1xuICAgICAgcmV0dXJuICcnO1xuICAgIH0gZWxzZSBpZiAoVVJJLmlwNl9leHByZXNzaW9uLnRlc3QocGFydHMuaG9zdG5hbWUpKSB7XG4gICAgICB0ICs9ICdbJyArIHBhcnRzLmhvc3RuYW1lICsgJ10nO1xuICAgIH0gZWxzZSB7XG4gICAgICB0ICs9IHBhcnRzLmhvc3RuYW1lO1xuICAgIH1cblxuICAgIGlmIChwYXJ0cy5wb3J0KSB7XG4gICAgICB0ICs9ICc6JyArIHBhcnRzLnBvcnQ7XG4gICAgfVxuXG4gICAgcmV0dXJuIHQ7XG4gIH07XG4gIFVSSS5idWlsZEF1dGhvcml0eSA9IGZ1bmN0aW9uKHBhcnRzKSB7XG4gICAgcmV0dXJuIFVSSS5idWlsZFVzZXJpbmZvKHBhcnRzKSArIFVSSS5idWlsZEhvc3QocGFydHMpO1xuICB9O1xuICBVUkkuYnVpbGRVc2VyaW5mbyA9IGZ1bmN0aW9uKHBhcnRzKSB7XG4gICAgdmFyIHQgPSAnJztcblxuICAgIGlmIChwYXJ0cy51c2VybmFtZSkge1xuICAgICAgdCArPSBVUkkuZW5jb2RlKHBhcnRzLnVzZXJuYW1lKTtcblxuICAgICAgaWYgKHBhcnRzLnBhc3N3b3JkKSB7XG4gICAgICAgIHQgKz0gJzonICsgVVJJLmVuY29kZShwYXJ0cy5wYXNzd29yZCk7XG4gICAgICB9XG5cbiAgICAgIHQgKz0gJ0AnO1xuICAgIH1cblxuICAgIHJldHVybiB0O1xuICB9O1xuICBVUkkuYnVpbGRRdWVyeSA9IGZ1bmN0aW9uKGRhdGEsIGR1cGxpY2F0ZVF1ZXJ5UGFyYW1ldGVycywgZXNjYXBlUXVlcnlTcGFjZSkge1xuICAgIC8vIGFjY29yZGluZyB0byBodHRwOi8vdG9vbHMuaWV0Zi5vcmcvaHRtbC9yZmMzOTg2IG9yIGh0dHA6Ly9sYWJzLmFwYWNoZS5vcmcvd2ViYXJjaC91cmkvcmZjL3JmYzM5ODYuaHRtbFxuICAgIC8vIGJlaW5nIMK7LS5ffiEkJicoKSorLDs9OkAvP8KrICVIRVggYW5kIGFsbnVtIGFyZSBhbGxvd2VkXG4gICAgLy8gdGhlIFJGQyBleHBsaWNpdGx5IHN0YXRlcyA/L2ZvbyBiZWluZyBhIHZhbGlkIHVzZSBjYXNlLCBubyBtZW50aW9uIG9mIHBhcmFtZXRlciBzeW50YXghXG4gICAgLy8gVVJJLmpzIHRyZWF0cyB0aGUgcXVlcnkgc3RyaW5nIGFzIGJlaW5nIGFwcGxpY2F0aW9uL3gtd3d3LWZvcm0tdXJsZW5jb2RlZFxuICAgIC8vIHNlZSBodHRwOi8vd3d3LnczLm9yZy9UUi9SRUMtaHRtbDQwL2ludGVyYWN0L2Zvcm1zLmh0bWwjZm9ybS1jb250ZW50LXR5cGVcblxuICAgIHZhciB0ID0gJyc7XG4gICAgdmFyIHVuaXF1ZSwga2V5LCBpLCBsZW5ndGg7XG4gICAgZm9yIChrZXkgaW4gZGF0YSkge1xuICAgICAgaWYgKGhhc093bi5jYWxsKGRhdGEsIGtleSkgJiYga2V5KSB7XG4gICAgICAgIGlmIChpc0FycmF5KGRhdGFba2V5XSkpIHtcbiAgICAgICAgICB1bmlxdWUgPSB7fTtcbiAgICAgICAgICBmb3IgKGkgPSAwLCBsZW5ndGggPSBkYXRhW2tleV0ubGVuZ3RoOyBpIDwgbGVuZ3RoOyBpKyspIHtcbiAgICAgICAgICAgIGlmIChkYXRhW2tleV1baV0gIT09IHVuZGVmaW5lZCAmJiB1bmlxdWVbZGF0YVtrZXldW2ldICsgJyddID09PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgICAgdCArPSAnJicgKyBVUkkuYnVpbGRRdWVyeVBhcmFtZXRlcihrZXksIGRhdGFba2V5XVtpXSwgZXNjYXBlUXVlcnlTcGFjZSk7XG4gICAgICAgICAgICAgIGlmIChkdXBsaWNhdGVRdWVyeVBhcmFtZXRlcnMgIT09IHRydWUpIHtcbiAgICAgICAgICAgICAgICB1bmlxdWVbZGF0YVtrZXldW2ldICsgJyddID0gdHJ1ZTtcbiAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgfVxuICAgICAgICAgIH1cbiAgICAgICAgfSBlbHNlIGlmIChkYXRhW2tleV0gIT09IHVuZGVmaW5lZCkge1xuICAgICAgICAgIHQgKz0gJyYnICsgVVJJLmJ1aWxkUXVlcnlQYXJhbWV0ZXIoa2V5LCBkYXRhW2tleV0sIGVzY2FwZVF1ZXJ5U3BhY2UpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfVxuXG4gICAgcmV0dXJuIHQuc3Vic3RyaW5nKDEpO1xuICB9O1xuICBVUkkuYnVpbGRRdWVyeVBhcmFtZXRlciA9IGZ1bmN0aW9uKG5hbWUsIHZhbHVlLCBlc2NhcGVRdWVyeVNwYWNlKSB7XG4gICAgLy8gaHR0cDovL3d3dy53My5vcmcvVFIvUkVDLWh0bWw0MC9pbnRlcmFjdC9mb3Jtcy5odG1sI2Zvcm0tY29udGVudC10eXBlIC0tIGFwcGxpY2F0aW9uL3gtd3d3LWZvcm0tdXJsZW5jb2RlZFxuICAgIC8vIGRvbid0IGFwcGVuZCBcIj1cIiBmb3IgbnVsbCB2YWx1ZXMsIGFjY29yZGluZyB0byBodHRwOi8vZHZjcy53My5vcmcvaGcvdXJsL3Jhdy1maWxlL3RpcC9PdmVydmlldy5odG1sI3VybC1wYXJhbWV0ZXItc2VyaWFsaXphdGlvblxuICAgIHJldHVybiBVUkkuZW5jb2RlUXVlcnkobmFtZSwgZXNjYXBlUXVlcnlTcGFjZSkgKyAodmFsdWUgIT09IG51bGwgPyAnPScgKyBVUkkuZW5jb2RlUXVlcnkodmFsdWUsIGVzY2FwZVF1ZXJ5U3BhY2UpIDogJycpO1xuICB9O1xuXG4gIFVSSS5hZGRRdWVyeSA9IGZ1bmN0aW9uKGRhdGEsIG5hbWUsIHZhbHVlKSB7XG4gICAgaWYgKHR5cGVvZiBuYW1lID09PSAnb2JqZWN0Jykge1xuICAgICAgZm9yICh2YXIga2V5IGluIG5hbWUpIHtcbiAgICAgICAgaWYgKGhhc093bi5jYWxsKG5hbWUsIGtleSkpIHtcbiAgICAgICAgICBVUkkuYWRkUXVlcnkoZGF0YSwga2V5LCBuYW1lW2tleV0pO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfSBlbHNlIGlmICh0eXBlb2YgbmFtZSA9PT0gJ3N0cmluZycpIHtcbiAgICAgIGlmIChkYXRhW25hbWVdID09PSB1bmRlZmluZWQpIHtcbiAgICAgICAgZGF0YVtuYW1lXSA9IHZhbHVlO1xuICAgICAgICByZXR1cm47XG4gICAgICB9IGVsc2UgaWYgKHR5cGVvZiBkYXRhW25hbWVdID09PSAnc3RyaW5nJykge1xuICAgICAgICBkYXRhW25hbWVdID0gW2RhdGFbbmFtZV1dO1xuICAgICAgfVxuXG4gICAgICBpZiAoIWlzQXJyYXkodmFsdWUpKSB7XG4gICAgICAgIHZhbHVlID0gW3ZhbHVlXTtcbiAgICAgIH1cblxuICAgICAgZGF0YVtuYW1lXSA9IChkYXRhW25hbWVdIHx8IFtdKS5jb25jYXQodmFsdWUpO1xuICAgIH0gZWxzZSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdVUkkuYWRkUXVlcnkoKSBhY2NlcHRzIGFuIG9iamVjdCwgc3RyaW5nIGFzIHRoZSBuYW1lIHBhcmFtZXRlcicpO1xuICAgIH1cbiAgfTtcbiAgVVJJLnJlbW92ZVF1ZXJ5ID0gZnVuY3Rpb24oZGF0YSwgbmFtZSwgdmFsdWUpIHtcbiAgICB2YXIgaSwgbGVuZ3RoLCBrZXk7XG5cbiAgICBpZiAoaXNBcnJheShuYW1lKSkge1xuICAgICAgZm9yIChpID0gMCwgbGVuZ3RoID0gbmFtZS5sZW5ndGg7IGkgPCBsZW5ndGg7IGkrKykge1xuICAgICAgICBkYXRhW25hbWVbaV1dID0gdW5kZWZpbmVkO1xuICAgICAgfVxuICAgIH0gZWxzZSBpZiAoZ2V0VHlwZShuYW1lKSA9PT0gJ1JlZ0V4cCcpIHtcbiAgICAgIGZvciAoa2V5IGluIGRhdGEpIHtcbiAgICAgICAgaWYgKG5hbWUudGVzdChrZXkpKSB7XG4gICAgICAgICAgZGF0YVtrZXldID0gdW5kZWZpbmVkO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfSBlbHNlIGlmICh0eXBlb2YgbmFtZSA9PT0gJ29iamVjdCcpIHtcbiAgICAgIGZvciAoa2V5IGluIG5hbWUpIHtcbiAgICAgICAgaWYgKGhhc093bi5jYWxsKG5hbWUsIGtleSkpIHtcbiAgICAgICAgICBVUkkucmVtb3ZlUXVlcnkoZGF0YSwga2V5LCBuYW1lW2tleV0pO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfSBlbHNlIGlmICh0eXBlb2YgbmFtZSA9PT0gJ3N0cmluZycpIHtcbiAgICAgIGlmICh2YWx1ZSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIGlmIChnZXRUeXBlKHZhbHVlKSA9PT0gJ1JlZ0V4cCcpIHtcbiAgICAgICAgICBpZiAoIWlzQXJyYXkoZGF0YVtuYW1lXSkgJiYgdmFsdWUudGVzdChkYXRhW25hbWVdKSkge1xuICAgICAgICAgICAgZGF0YVtuYW1lXSA9IHVuZGVmaW5lZDtcbiAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgZGF0YVtuYW1lXSA9IGZpbHRlckFycmF5VmFsdWVzKGRhdGFbbmFtZV0sIHZhbHVlKTtcbiAgICAgICAgICB9XG4gICAgICAgIH0gZWxzZSBpZiAoZGF0YVtuYW1lXSA9PT0gU3RyaW5nKHZhbHVlKSAmJiAoIWlzQXJyYXkodmFsdWUpIHx8IHZhbHVlLmxlbmd0aCA9PT0gMSkpIHtcbiAgICAgICAgICBkYXRhW25hbWVdID0gdW5kZWZpbmVkO1xuICAgICAgICB9IGVsc2UgaWYgKGlzQXJyYXkoZGF0YVtuYW1lXSkpIHtcbiAgICAgICAgICBkYXRhW25hbWVdID0gZmlsdGVyQXJyYXlWYWx1ZXMoZGF0YVtuYW1lXSwgdmFsdWUpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2Uge1xuICAgICAgICBkYXRhW25hbWVdID0gdW5kZWZpbmVkO1xuICAgICAgfVxuICAgIH0gZWxzZSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdVUkkucmVtb3ZlUXVlcnkoKSBhY2NlcHRzIGFuIG9iamVjdCwgc3RyaW5nLCBSZWdFeHAgYXMgdGhlIGZpcnN0IHBhcmFtZXRlcicpO1xuICAgIH1cbiAgfTtcbiAgVVJJLmhhc1F1ZXJ5ID0gZnVuY3Rpb24oZGF0YSwgbmFtZSwgdmFsdWUsIHdpdGhpbkFycmF5KSB7XG4gICAgaWYgKHR5cGVvZiBuYW1lID09PSAnb2JqZWN0Jykge1xuICAgICAgZm9yICh2YXIga2V5IGluIG5hbWUpIHtcbiAgICAgICAgaWYgKGhhc093bi5jYWxsKG5hbWUsIGtleSkpIHtcbiAgICAgICAgICBpZiAoIVVSSS5oYXNRdWVyeShkYXRhLCBrZXksIG5hbWVba2V5XSkpIHtcbiAgICAgICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgIH1cblxuICAgICAgcmV0dXJuIHRydWU7XG4gICAgfSBlbHNlIGlmICh0eXBlb2YgbmFtZSAhPT0gJ3N0cmluZycpIHtcbiAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ1VSSS5oYXNRdWVyeSgpIGFjY2VwdHMgYW4gb2JqZWN0LCBzdHJpbmcgYXMgdGhlIG5hbWUgcGFyYW1ldGVyJyk7XG4gICAgfVxuXG4gICAgc3dpdGNoIChnZXRUeXBlKHZhbHVlKSkge1xuICAgICAgY2FzZSAnVW5kZWZpbmVkJzpcbiAgICAgICAgLy8gdHJ1ZSBpZiBleGlzdHMgKGJ1dCBtYXkgYmUgZW1wdHkpXG4gICAgICAgIHJldHVybiBuYW1lIGluIGRhdGE7IC8vIGRhdGFbbmFtZV0gIT09IHVuZGVmaW5lZDtcblxuICAgICAgY2FzZSAnQm9vbGVhbic6XG4gICAgICAgIC8vIHRydWUgaWYgZXhpc3RzIGFuZCBub24tZW1wdHlcbiAgICAgICAgdmFyIF9ib29seSA9IEJvb2xlYW4oaXNBcnJheShkYXRhW25hbWVdKSA/IGRhdGFbbmFtZV0ubGVuZ3RoIDogZGF0YVtuYW1lXSk7XG4gICAgICAgIHJldHVybiB2YWx1ZSA9PT0gX2Jvb2x5O1xuXG4gICAgICBjYXNlICdGdW5jdGlvbic6XG4gICAgICAgIC8vIGFsbG93IGNvbXBsZXggY29tcGFyaXNvblxuICAgICAgICByZXR1cm4gISF2YWx1ZShkYXRhW25hbWVdLCBuYW1lLCBkYXRhKTtcblxuICAgICAgY2FzZSAnQXJyYXknOlxuICAgICAgICBpZiAoIWlzQXJyYXkoZGF0YVtuYW1lXSkpIHtcbiAgICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICAgIH1cblxuICAgICAgICB2YXIgb3AgPSB3aXRoaW5BcnJheSA/IGFycmF5Q29udGFpbnMgOiBhcnJheXNFcXVhbDtcbiAgICAgICAgcmV0dXJuIG9wKGRhdGFbbmFtZV0sIHZhbHVlKTtcblxuICAgICAgY2FzZSAnUmVnRXhwJzpcbiAgICAgICAgaWYgKCFpc0FycmF5KGRhdGFbbmFtZV0pKSB7XG4gICAgICAgICAgcmV0dXJuIEJvb2xlYW4oZGF0YVtuYW1lXSAmJiBkYXRhW25hbWVdLm1hdGNoKHZhbHVlKSk7XG4gICAgICAgIH1cblxuICAgICAgICBpZiAoIXdpdGhpbkFycmF5KSB7XG4gICAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgICB9XG5cbiAgICAgICAgcmV0dXJuIGFycmF5Q29udGFpbnMoZGF0YVtuYW1lXSwgdmFsdWUpO1xuXG4gICAgICBjYXNlICdOdW1iZXInOlxuICAgICAgICB2YWx1ZSA9IFN0cmluZyh2YWx1ZSk7XG4gICAgICAgIC8qIGZhbGxzIHRocm91Z2ggKi9cbiAgICAgIGNhc2UgJ1N0cmluZyc6XG4gICAgICAgIGlmICghaXNBcnJheShkYXRhW25hbWVdKSkge1xuICAgICAgICAgIHJldHVybiBkYXRhW25hbWVdID09PSB2YWx1ZTtcbiAgICAgICAgfVxuXG4gICAgICAgIGlmICghd2l0aGluQXJyYXkpIHtcbiAgICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICAgIH1cblxuICAgICAgICByZXR1cm4gYXJyYXlDb250YWlucyhkYXRhW25hbWVdLCB2YWx1ZSk7XG5cbiAgICAgIGRlZmF1bHQ6XG4gICAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ1VSSS5oYXNRdWVyeSgpIGFjY2VwdHMgdW5kZWZpbmVkLCBib29sZWFuLCBzdHJpbmcsIG51bWJlciwgUmVnRXhwLCBGdW5jdGlvbiBhcyB0aGUgdmFsdWUgcGFyYW1ldGVyJyk7XG4gICAgfVxuICB9O1xuXG5cbiAgVVJJLmNvbW1vblBhdGggPSBmdW5jdGlvbihvbmUsIHR3bykge1xuICAgIHZhciBsZW5ndGggPSBNYXRoLm1pbihvbmUubGVuZ3RoLCB0d28ubGVuZ3RoKTtcbiAgICB2YXIgcG9zO1xuXG4gICAgLy8gZmluZCBmaXJzdCBub24tbWF0Y2hpbmcgY2hhcmFjdGVyXG4gICAgZm9yIChwb3MgPSAwOyBwb3MgPCBsZW5ndGg7IHBvcysrKSB7XG4gICAgICBpZiAob25lLmNoYXJBdChwb3MpICE9PSB0d28uY2hhckF0KHBvcykpIHtcbiAgICAgICAgcG9zLS07XG4gICAgICAgIGJyZWFrO1xuICAgICAgfVxuICAgIH1cblxuICAgIGlmIChwb3MgPCAxKSB7XG4gICAgICByZXR1cm4gb25lLmNoYXJBdCgwKSA9PT0gdHdvLmNoYXJBdCgwKSAmJiBvbmUuY2hhckF0KDApID09PSAnLycgPyAnLycgOiAnJztcbiAgICB9XG5cbiAgICAvLyByZXZlcnQgdG8gbGFzdCAvXG4gICAgaWYgKG9uZS5jaGFyQXQocG9zKSAhPT0gJy8nIHx8IHR3by5jaGFyQXQocG9zKSAhPT0gJy8nKSB7XG4gICAgICBwb3MgPSBvbmUuc3Vic3RyaW5nKDAsIHBvcykubGFzdEluZGV4T2YoJy8nKTtcbiAgICB9XG5cbiAgICByZXR1cm4gb25lLnN1YnN0cmluZygwLCBwb3MgKyAxKTtcbiAgfTtcblxuICBVUkkud2l0aGluU3RyaW5nID0gZnVuY3Rpb24oc3RyaW5nLCBjYWxsYmFjaywgb3B0aW9ucykge1xuICAgIG9wdGlvbnMgfHwgKG9wdGlvbnMgPSB7fSk7XG4gICAgdmFyIF9zdGFydCA9IG9wdGlvbnMuc3RhcnQgfHwgVVJJLmZpbmRVcmkuc3RhcnQ7XG4gICAgdmFyIF9lbmQgPSBvcHRpb25zLmVuZCB8fCBVUkkuZmluZFVyaS5lbmQ7XG4gICAgdmFyIF90cmltID0gb3B0aW9ucy50cmltIHx8IFVSSS5maW5kVXJpLnRyaW07XG4gICAgdmFyIF9hdHRyaWJ1dGVPcGVuID0gL1thLXowLTktXT1bXCInXT8kL2k7XG5cbiAgICBfc3RhcnQubGFzdEluZGV4ID0gMDtcbiAgICB3aGlsZSAodHJ1ZSkge1xuICAgICAgdmFyIG1hdGNoID0gX3N0YXJ0LmV4ZWMoc3RyaW5nKTtcbiAgICAgIGlmICghbWF0Y2gpIHtcbiAgICAgICAgYnJlYWs7XG4gICAgICB9XG5cbiAgICAgIHZhciBzdGFydCA9IG1hdGNoLmluZGV4O1xuICAgICAgaWYgKG9wdGlvbnMuaWdub3JlSHRtbCkge1xuICAgICAgICAvLyBhdHRyaWJ1dChlPVtcIiddPyQpXG4gICAgICAgIHZhciBhdHRyaWJ1dGVPcGVuID0gc3RyaW5nLnNsaWNlKE1hdGgubWF4KHN0YXJ0IC0gMywgMCksIHN0YXJ0KTtcbiAgICAgICAgaWYgKGF0dHJpYnV0ZU9wZW4gJiYgX2F0dHJpYnV0ZU9wZW4udGVzdChhdHRyaWJ1dGVPcGVuKSkge1xuICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICB9XG4gICAgICB9XG5cbiAgICAgIHZhciBlbmQgPSBzdGFydCArIHN0cmluZy5zbGljZShzdGFydCkuc2VhcmNoKF9lbmQpO1xuICAgICAgdmFyIHNsaWNlID0gc3RyaW5nLnNsaWNlKHN0YXJ0LCBlbmQpLnJlcGxhY2UoX3RyaW0sICcnKTtcbiAgICAgIGlmIChvcHRpb25zLmlnbm9yZSAmJiBvcHRpb25zLmlnbm9yZS50ZXN0KHNsaWNlKSkge1xuICAgICAgICBjb250aW51ZTtcbiAgICAgIH1cblxuICAgICAgZW5kID0gc3RhcnQgKyBzbGljZS5sZW5ndGg7XG4gICAgICB2YXIgcmVzdWx0ID0gY2FsbGJhY2soc2xpY2UsIHN0YXJ0LCBlbmQsIHN0cmluZyk7XG4gICAgICBzdHJpbmcgPSBzdHJpbmcuc2xpY2UoMCwgc3RhcnQpICsgcmVzdWx0ICsgc3RyaW5nLnNsaWNlKGVuZCk7XG4gICAgICBfc3RhcnQubGFzdEluZGV4ID0gc3RhcnQgKyByZXN1bHQubGVuZ3RoO1xuICAgIH1cblxuICAgIF9zdGFydC5sYXN0SW5kZXggPSAwO1xuICAgIHJldHVybiBzdHJpbmc7XG4gIH07XG5cbiAgVVJJLmVuc3VyZVZhbGlkSG9zdG5hbWUgPSBmdW5jdGlvbih2KSB7XG4gICAgLy8gVGhlb3JldGljYWxseSBVUklzIGFsbG93IHBlcmNlbnQtZW5jb2RpbmcgaW4gSG9zdG5hbWVzIChhY2NvcmRpbmcgdG8gUkZDIDM5ODYpXG4gICAgLy8gdGhleSBhcmUgbm90IHBhcnQgb2YgRE5TIGFuZCB0aGVyZWZvcmUgaWdub3JlZCBieSBVUkkuanNcblxuICAgIGlmICh2Lm1hdGNoKFVSSS5pbnZhbGlkX2hvc3RuYW1lX2NoYXJhY3RlcnMpKSB7XG4gICAgICAvLyB0ZXN0IHB1bnljb2RlXG4gICAgICBpZiAoIXB1bnljb2RlKSB7XG4gICAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ0hvc3RuYW1lIFwiJyArIHYgKyAnXCIgY29udGFpbnMgY2hhcmFjdGVycyBvdGhlciB0aGFuIFtBLVowLTkuLV0gYW5kIFB1bnljb2RlLmpzIGlzIG5vdCBhdmFpbGFibGUnKTtcbiAgICAgIH1cblxuICAgICAgaWYgKHB1bnljb2RlLnRvQVNDSUkodikubWF0Y2goVVJJLmludmFsaWRfaG9zdG5hbWVfY2hhcmFjdGVycykpIHtcbiAgICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignSG9zdG5hbWUgXCInICsgdiArICdcIiBjb250YWlucyBjaGFyYWN0ZXJzIG90aGVyIHRoYW4gW0EtWjAtOS4tXScpO1xuICAgICAgfVxuICAgIH1cbiAgfTtcblxuICAvLyBub0NvbmZsaWN0XG4gIFVSSS5ub0NvbmZsaWN0ID0gZnVuY3Rpb24ocmVtb3ZlQWxsKSB7XG4gICAgaWYgKHJlbW92ZUFsbCkge1xuICAgICAgdmFyIHVuY29uZmxpY3RlZCA9IHtcbiAgICAgICAgVVJJOiB0aGlzLm5vQ29uZmxpY3QoKVxuICAgICAgfTtcblxuICAgICAgaWYgKHJvb3QuVVJJVGVtcGxhdGUgJiYgdHlwZW9mIHJvb3QuVVJJVGVtcGxhdGUubm9Db25mbGljdCA9PT0gJ2Z1bmN0aW9uJykge1xuICAgICAgICB1bmNvbmZsaWN0ZWQuVVJJVGVtcGxhdGUgPSByb290LlVSSVRlbXBsYXRlLm5vQ29uZmxpY3QoKTtcbiAgICAgIH1cblxuICAgICAgaWYgKHJvb3QuSVB2NiAmJiB0eXBlb2Ygcm9vdC5JUHY2Lm5vQ29uZmxpY3QgPT09ICdmdW5jdGlvbicpIHtcbiAgICAgICAgdW5jb25mbGljdGVkLklQdjYgPSByb290LklQdjYubm9Db25mbGljdCgpO1xuICAgICAgfVxuXG4gICAgICBpZiAocm9vdC5TZWNvbmRMZXZlbERvbWFpbnMgJiYgdHlwZW9mIHJvb3QuU2Vjb25kTGV2ZWxEb21haW5zLm5vQ29uZmxpY3QgPT09ICdmdW5jdGlvbicpIHtcbiAgICAgICAgdW5jb25mbGljdGVkLlNlY29uZExldmVsRG9tYWlucyA9IHJvb3QuU2Vjb25kTGV2ZWxEb21haW5zLm5vQ29uZmxpY3QoKTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIHVuY29uZmxpY3RlZDtcbiAgICB9IGVsc2UgaWYgKHJvb3QuVVJJID09PSB0aGlzKSB7XG4gICAgICByb290LlVSSSA9IF9VUkk7XG4gICAgfVxuXG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG5cbiAgcC5idWlsZCA9IGZ1bmN0aW9uKGRlZmVyQnVpbGQpIHtcbiAgICBpZiAoZGVmZXJCdWlsZCA9PT0gdHJ1ZSkge1xuICAgICAgdGhpcy5fZGVmZXJyZWRfYnVpbGQgPSB0cnVlO1xuICAgIH0gZWxzZSBpZiAoZGVmZXJCdWlsZCA9PT0gdW5kZWZpbmVkIHx8IHRoaXMuX2RlZmVycmVkX2J1aWxkKSB7XG4gICAgICB0aGlzLl9zdHJpbmcgPSBVUkkuYnVpbGQodGhpcy5fcGFydHMpO1xuICAgICAgdGhpcy5fZGVmZXJyZWRfYnVpbGQgPSBmYWxzZTtcbiAgICB9XG5cbiAgICByZXR1cm4gdGhpcztcbiAgfTtcblxuICBwLmNsb25lID0gZnVuY3Rpb24oKSB7XG4gICAgcmV0dXJuIG5ldyBVUkkodGhpcyk7XG4gIH07XG5cbiAgcC52YWx1ZU9mID0gcC50b1N0cmluZyA9IGZ1bmN0aW9uKCkge1xuICAgIHJldHVybiB0aGlzLmJ1aWxkKGZhbHNlKS5fc3RyaW5nO1xuICB9O1xuXG5cbiAgZnVuY3Rpb24gZ2VuZXJhdGVTaW1wbGVBY2Nlc3NvcihfcGFydCl7XG4gICAgcmV0dXJuIGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgICBpZiAodiA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICAgIHJldHVybiB0aGlzLl9wYXJ0c1tfcGFydF0gfHwgJyc7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0aGlzLl9wYXJ0c1tfcGFydF0gPSB2IHx8IG51bGw7XG4gICAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgICAgcmV0dXJuIHRoaXM7XG4gICAgICB9XG4gICAgfTtcbiAgfVxuXG4gIGZ1bmN0aW9uIGdlbmVyYXRlUHJlZml4QWNjZXNzb3IoX3BhcnQsIF9rZXkpe1xuICAgIHJldHVybiBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgICByZXR1cm4gdGhpcy5fcGFydHNbX3BhcnRdIHx8ICcnO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgaWYgKHYgIT09IG51bGwpIHtcbiAgICAgICAgICB2ID0gdiArICcnO1xuICAgICAgICAgIGlmICh2LmNoYXJBdCgwKSA9PT0gX2tleSkge1xuICAgICAgICAgICAgdiA9IHYuc3Vic3RyaW5nKDEpO1xuICAgICAgICAgIH1cbiAgICAgICAgfVxuXG4gICAgICAgIHRoaXMuX3BhcnRzW19wYXJ0XSA9IHY7XG4gICAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgICAgcmV0dXJuIHRoaXM7XG4gICAgICB9XG4gICAgfTtcbiAgfVxuXG4gIHAucHJvdG9jb2wgPSBnZW5lcmF0ZVNpbXBsZUFjY2Vzc29yKCdwcm90b2NvbCcpO1xuICBwLnVzZXJuYW1lID0gZ2VuZXJhdGVTaW1wbGVBY2Nlc3NvcigndXNlcm5hbWUnKTtcbiAgcC5wYXNzd29yZCA9IGdlbmVyYXRlU2ltcGxlQWNjZXNzb3IoJ3Bhc3N3b3JkJyk7XG4gIHAuaG9zdG5hbWUgPSBnZW5lcmF0ZVNpbXBsZUFjY2Vzc29yKCdob3N0bmFtZScpO1xuICBwLnBvcnQgPSBnZW5lcmF0ZVNpbXBsZUFjY2Vzc29yKCdwb3J0Jyk7XG4gIHAucXVlcnkgPSBnZW5lcmF0ZVByZWZpeEFjY2Vzc29yKCdxdWVyeScsICc/Jyk7XG4gIHAuZnJhZ21lbnQgPSBnZW5lcmF0ZVByZWZpeEFjY2Vzc29yKCdmcmFnbWVudCcsICcjJyk7XG5cbiAgcC5zZWFyY2ggPSBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgIHZhciB0ID0gdGhpcy5xdWVyeSh2LCBidWlsZCk7XG4gICAgcmV0dXJuIHR5cGVvZiB0ID09PSAnc3RyaW5nJyAmJiB0Lmxlbmd0aCA/ICgnPycgKyB0KSA6IHQ7XG4gIH07XG4gIHAuaGFzaCA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgdmFyIHQgPSB0aGlzLmZyYWdtZW50KHYsIGJ1aWxkKTtcbiAgICByZXR1cm4gdHlwZW9mIHQgPT09ICdzdHJpbmcnICYmIHQubGVuZ3RoID8gKCcjJyArIHQpIDogdDtcbiAgfTtcblxuICBwLnBhdGhuYW1lID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkIHx8IHYgPT09IHRydWUpIHtcbiAgICAgIHZhciByZXMgPSB0aGlzLl9wYXJ0cy5wYXRoIHx8ICh0aGlzLl9wYXJ0cy5ob3N0bmFtZSA/ICcvJyA6ICcnKTtcbiAgICAgIHJldHVybiB2ID8gKHRoaXMuX3BhcnRzLnVybiA/IFVSSS5kZWNvZGVVcm5QYXRoIDogVVJJLmRlY29kZVBhdGgpKHJlcykgOiByZXM7XG4gICAgfSBlbHNlIHtcbiAgICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgICAgdGhpcy5fcGFydHMucGF0aCA9IHYgPyBVUkkucmVjb2RlVXJuUGF0aCh2KSA6ICcnO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdGhpcy5fcGFydHMucGF0aCA9IHYgPyBVUkkucmVjb2RlUGF0aCh2KSA6ICcvJztcbiAgICAgIH1cbiAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgIHJldHVybiB0aGlzO1xuICAgIH1cbiAgfTtcbiAgcC5wYXRoID0gcC5wYXRobmFtZTtcbiAgcC5ocmVmID0gZnVuY3Rpb24oaHJlZiwgYnVpbGQpIHtcbiAgICB2YXIga2V5O1xuXG4gICAgaWYgKGhyZWYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHRoaXMudG9TdHJpbmcoKTtcbiAgICB9XG5cbiAgICB0aGlzLl9zdHJpbmcgPSAnJztcbiAgICB0aGlzLl9wYXJ0cyA9IFVSSS5fcGFydHMoKTtcblxuICAgIHZhciBfVVJJID0gaHJlZiBpbnN0YW5jZW9mIFVSSTtcbiAgICB2YXIgX29iamVjdCA9IHR5cGVvZiBocmVmID09PSAnb2JqZWN0JyAmJiAoaHJlZi5ob3N0bmFtZSB8fCBocmVmLnBhdGggfHwgaHJlZi5wYXRobmFtZSk7XG4gICAgaWYgKGhyZWYubm9kZU5hbWUpIHtcbiAgICAgIHZhciBhdHRyaWJ1dGUgPSBVUkkuZ2V0RG9tQXR0cmlidXRlKGhyZWYpO1xuICAgICAgaHJlZiA9IGhyZWZbYXR0cmlidXRlXSB8fCAnJztcbiAgICAgIF9vYmplY3QgPSBmYWxzZTtcbiAgICB9XG5cbiAgICAvLyB3aW5kb3cubG9jYXRpb24gaXMgcmVwb3J0ZWQgdG8gYmUgYW4gb2JqZWN0LCBidXQgaXQncyBub3QgdGhlIHNvcnRcbiAgICAvLyBvZiBvYmplY3Qgd2UncmUgbG9va2luZyBmb3I6XG4gICAgLy8gKiBsb2NhdGlvbi5wcm90b2NvbCBlbmRzIHdpdGggYSBjb2xvblxuICAgIC8vICogbG9jYXRpb24ucXVlcnkgIT0gb2JqZWN0LnNlYXJjaFxuICAgIC8vICogbG9jYXRpb24uaGFzaCAhPSBvYmplY3QuZnJhZ21lbnRcbiAgICAvLyBzaW1wbHkgc2VyaWFsaXppbmcgdGhlIHVua25vd24gb2JqZWN0IHNob3VsZCBkbyB0aGUgdHJpY2tcbiAgICAvLyAoZm9yIGxvY2F0aW9uLCBub3QgZm9yIGV2ZXJ5dGhpbmcuLi4pXG4gICAgaWYgKCFfVVJJICYmIF9vYmplY3QgJiYgaHJlZi5wYXRobmFtZSAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBocmVmID0gaHJlZi50b1N0cmluZygpO1xuICAgIH1cblxuICAgIGlmICh0eXBlb2YgaHJlZiA9PT0gJ3N0cmluZycgfHwgaHJlZiBpbnN0YW5jZW9mIFN0cmluZykge1xuICAgICAgdGhpcy5fcGFydHMgPSBVUkkucGFyc2UoU3RyaW5nKGhyZWYpLCB0aGlzLl9wYXJ0cyk7XG4gICAgfSBlbHNlIGlmIChfVVJJIHx8IF9vYmplY3QpIHtcbiAgICAgIHZhciBzcmMgPSBfVVJJID8gaHJlZi5fcGFydHMgOiBocmVmO1xuICAgICAgZm9yIChrZXkgaW4gc3JjKSB7XG4gICAgICAgIGlmIChoYXNPd24uY2FsbCh0aGlzLl9wYXJ0cywga2V5KSkge1xuICAgICAgICAgIHRoaXMuX3BhcnRzW2tleV0gPSBzcmNba2V5XTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH0gZWxzZSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdpbnZhbGlkIGlucHV0Jyk7XG4gICAgfVxuXG4gICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgIHJldHVybiB0aGlzO1xuICB9O1xuXG4gIC8vIGlkZW50aWZpY2F0aW9uIGFjY2Vzc29yc1xuICBwLmlzID0gZnVuY3Rpb24od2hhdCkge1xuICAgIHZhciBpcCA9IGZhbHNlO1xuICAgIHZhciBpcDQgPSBmYWxzZTtcbiAgICB2YXIgaXA2ID0gZmFsc2U7XG4gICAgdmFyIG5hbWUgPSBmYWxzZTtcbiAgICB2YXIgc2xkID0gZmFsc2U7XG4gICAgdmFyIGlkbiA9IGZhbHNlO1xuICAgIHZhciBwdW55Y29kZSA9IGZhbHNlO1xuICAgIHZhciByZWxhdGl2ZSA9ICF0aGlzLl9wYXJ0cy51cm47XG5cbiAgICBpZiAodGhpcy5fcGFydHMuaG9zdG5hbWUpIHtcbiAgICAgIHJlbGF0aXZlID0gZmFsc2U7XG4gICAgICBpcDQgPSBVUkkuaXA0X2V4cHJlc3Npb24udGVzdCh0aGlzLl9wYXJ0cy5ob3N0bmFtZSk7XG4gICAgICBpcDYgPSBVUkkuaXA2X2V4cHJlc3Npb24udGVzdCh0aGlzLl9wYXJ0cy5ob3N0bmFtZSk7XG4gICAgICBpcCA9IGlwNCB8fCBpcDY7XG4gICAgICBuYW1lID0gIWlwO1xuICAgICAgc2xkID0gbmFtZSAmJiBTTEQgJiYgU0xELmhhcyh0aGlzLl9wYXJ0cy5ob3N0bmFtZSk7XG4gICAgICBpZG4gPSBuYW1lICYmIFVSSS5pZG5fZXhwcmVzc2lvbi50ZXN0KHRoaXMuX3BhcnRzLmhvc3RuYW1lKTtcbiAgICAgIHB1bnljb2RlID0gbmFtZSAmJiBVUkkucHVueWNvZGVfZXhwcmVzc2lvbi50ZXN0KHRoaXMuX3BhcnRzLmhvc3RuYW1lKTtcbiAgICB9XG5cbiAgICBzd2l0Y2ggKHdoYXQudG9Mb3dlckNhc2UoKSkge1xuICAgICAgY2FzZSAncmVsYXRpdmUnOlxuICAgICAgICByZXR1cm4gcmVsYXRpdmU7XG5cbiAgICAgIGNhc2UgJ2Fic29sdXRlJzpcbiAgICAgICAgcmV0dXJuICFyZWxhdGl2ZTtcblxuICAgICAgLy8gaG9zdG5hbWUgaWRlbnRpZmljYXRpb25cbiAgICAgIGNhc2UgJ2RvbWFpbic6XG4gICAgICBjYXNlICduYW1lJzpcbiAgICAgICAgcmV0dXJuIG5hbWU7XG5cbiAgICAgIGNhc2UgJ3NsZCc6XG4gICAgICAgIHJldHVybiBzbGQ7XG5cbiAgICAgIGNhc2UgJ2lwJzpcbiAgICAgICAgcmV0dXJuIGlwO1xuXG4gICAgICBjYXNlICdpcDQnOlxuICAgICAgY2FzZSAnaXB2NCc6XG4gICAgICBjYXNlICdpbmV0NCc6XG4gICAgICAgIHJldHVybiBpcDQ7XG5cbiAgICAgIGNhc2UgJ2lwNic6XG4gICAgICBjYXNlICdpcHY2JzpcbiAgICAgIGNhc2UgJ2luZXQ2JzpcbiAgICAgICAgcmV0dXJuIGlwNjtcblxuICAgICAgY2FzZSAnaWRuJzpcbiAgICAgICAgcmV0dXJuIGlkbjtcblxuICAgICAgY2FzZSAndXJsJzpcbiAgICAgICAgcmV0dXJuICF0aGlzLl9wYXJ0cy51cm47XG5cbiAgICAgIGNhc2UgJ3Vybic6XG4gICAgICAgIHJldHVybiAhIXRoaXMuX3BhcnRzLnVybjtcblxuICAgICAgY2FzZSAncHVueWNvZGUnOlxuICAgICAgICByZXR1cm4gcHVueWNvZGU7XG4gICAgfVxuXG4gICAgcmV0dXJuIG51bGw7XG4gIH07XG5cbiAgLy8gY29tcG9uZW50IHNwZWNpZmljIGlucHV0IHZhbGlkYXRpb25cbiAgdmFyIF9wcm90b2NvbCA9IHAucHJvdG9jb2w7XG4gIHZhciBfcG9ydCA9IHAucG9ydDtcbiAgdmFyIF9ob3N0bmFtZSA9IHAuaG9zdG5hbWU7XG5cbiAgcC5wcm90b2NvbCA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgaWYgKHYgIT09IHVuZGVmaW5lZCkge1xuICAgICAgaWYgKHYpIHtcbiAgICAgICAgLy8gYWNjZXB0IHRyYWlsaW5nIDovL1xuICAgICAgICB2ID0gdi5yZXBsYWNlKC86KFxcL1xcLyk/JC8sICcnKTtcblxuICAgICAgICBpZiAoIXYubWF0Y2goVVJJLnByb3RvY29sX2V4cHJlc3Npb24pKSB7XG4gICAgICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignUHJvdG9jb2wgXCInICsgdiArICdcIiBjb250YWlucyBjaGFyYWN0ZXJzIG90aGVyIHRoYW4gW0EtWjAtOS4rLV0gb3IgZG9lc25cXCd0IHN0YXJ0IHdpdGggW0EtWl0nKTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH1cbiAgICByZXR1cm4gX3Byb3RvY29sLmNhbGwodGhpcywgdiwgYnVpbGQpO1xuICB9O1xuICBwLnNjaGVtZSA9IHAucHJvdG9jb2w7XG4gIHAucG9ydCA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgaWYgKHRoaXMuX3BhcnRzLnVybikge1xuICAgICAgcmV0dXJuIHYgPT09IHVuZGVmaW5lZCA/ICcnIDogdGhpcztcbiAgICB9XG5cbiAgICBpZiAodiAhPT0gdW5kZWZpbmVkKSB7XG4gICAgICBpZiAodiA9PT0gMCkge1xuICAgICAgICB2ID0gbnVsbDtcbiAgICAgIH1cblxuICAgICAgaWYgKHYpIHtcbiAgICAgICAgdiArPSAnJztcbiAgICAgICAgaWYgKHYuY2hhckF0KDApID09PSAnOicpIHtcbiAgICAgICAgICB2ID0gdi5zdWJzdHJpbmcoMSk7XG4gICAgICAgIH1cblxuICAgICAgICBpZiAodi5tYXRjaCgvW14wLTldLykpIHtcbiAgICAgICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdQb3J0IFwiJyArIHYgKyAnXCIgY29udGFpbnMgY2hhcmFjdGVycyBvdGhlciB0aGFuIFswLTldJyk7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG4gICAgcmV0dXJuIF9wb3J0LmNhbGwodGhpcywgdiwgYnVpbGQpO1xuICB9O1xuICBwLmhvc3RuYW1lID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodGhpcy5fcGFydHMudXJuKSB7XG4gICAgICByZXR1cm4gdiA9PT0gdW5kZWZpbmVkID8gJycgOiB0aGlzO1xuICAgIH1cblxuICAgIGlmICh2ICE9PSB1bmRlZmluZWQpIHtcbiAgICAgIHZhciB4ID0ge307XG4gICAgICB2YXIgcmVzID0gVVJJLnBhcnNlSG9zdCh2LCB4KTtcbiAgICAgIGlmIChyZXMgIT09ICcvJykge1xuICAgICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdIb3N0bmFtZSBcIicgKyB2ICsgJ1wiIGNvbnRhaW5zIGNoYXJhY3RlcnMgb3RoZXIgdGhhbiBbQS1aMC05Li1dJyk7XG4gICAgICB9XG5cbiAgICAgIHYgPSB4Lmhvc3RuYW1lO1xuICAgIH1cbiAgICByZXR1cm4gX2hvc3RuYW1lLmNhbGwodGhpcywgdiwgYnVpbGQpO1xuICB9O1xuXG4gIC8vIGNvbXBvdW5kIGFjY2Vzc29yc1xuICBwLm9yaWdpbiA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgdmFyIHBhcnRzO1xuXG4gICAgaWYgKHRoaXMuX3BhcnRzLnVybikge1xuICAgICAgcmV0dXJuIHYgPT09IHVuZGVmaW5lZCA/ICcnIDogdGhpcztcbiAgICB9XG5cbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICB2YXIgcHJvdG9jb2wgPSB0aGlzLnByb3RvY29sKCk7XG4gICAgICB2YXIgYXV0aG9yaXR5ID0gdGhpcy5hdXRob3JpdHkoKTtcbiAgICAgIGlmICghYXV0aG9yaXR5KSByZXR1cm4gJyc7XG4gICAgICByZXR1cm4gKHByb3RvY29sID8gcHJvdG9jb2wgKyAnOi8vJyA6ICcnKSArIHRoaXMuYXV0aG9yaXR5KCk7XG4gICAgfSBlbHNlIHtcbiAgICAgIHZhciBvcmlnaW4gPSBVUkkodik7XG4gICAgICB0aGlzXG4gICAgICAgIC5wcm90b2NvbChvcmlnaW4ucHJvdG9jb2woKSlcbiAgICAgICAgLmF1dGhvcml0eShvcmlnaW4uYXV0aG9yaXR5KCkpXG4gICAgICAgIC5idWlsZCghYnVpbGQpO1xuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfVxuICB9O1xuICBwLmhvc3QgPSBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgIHJldHVybiB2ID09PSB1bmRlZmluZWQgPyAnJyA6IHRoaXM7XG4gICAgfVxuXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHRoaXMuX3BhcnRzLmhvc3RuYW1lID8gVVJJLmJ1aWxkSG9zdCh0aGlzLl9wYXJ0cykgOiAnJztcbiAgICB9IGVsc2Uge1xuICAgICAgdmFyIHJlcyA9IFVSSS5wYXJzZUhvc3QodiwgdGhpcy5fcGFydHMpO1xuICAgICAgaWYgKHJlcyAhPT0gJy8nKSB7XG4gICAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ0hvc3RuYW1lIFwiJyArIHYgKyAnXCIgY29udGFpbnMgY2hhcmFjdGVycyBvdGhlciB0aGFuIFtBLVowLTkuLV0nKTtcbiAgICAgIH1cblxuICAgICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfVxuICB9O1xuICBwLmF1dGhvcml0eSA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgaWYgKHRoaXMuX3BhcnRzLnVybikge1xuICAgICAgcmV0dXJuIHYgPT09IHVuZGVmaW5lZCA/ICcnIDogdGhpcztcbiAgICB9XG5cbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICByZXR1cm4gdGhpcy5fcGFydHMuaG9zdG5hbWUgPyBVUkkuYnVpbGRBdXRob3JpdHkodGhpcy5fcGFydHMpIDogJyc7XG4gICAgfSBlbHNlIHtcbiAgICAgIHZhciByZXMgPSBVUkkucGFyc2VBdXRob3JpdHkodiwgdGhpcy5fcGFydHMpO1xuICAgICAgaWYgKHJlcyAhPT0gJy8nKSB7XG4gICAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ0hvc3RuYW1lIFwiJyArIHYgKyAnXCIgY29udGFpbnMgY2hhcmFjdGVycyBvdGhlciB0aGFuIFtBLVowLTkuLV0nKTtcbiAgICAgIH1cblxuICAgICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfVxuICB9O1xuICBwLnVzZXJpbmZvID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodGhpcy5fcGFydHMudXJuKSB7XG4gICAgICByZXR1cm4gdiA9PT0gdW5kZWZpbmVkID8gJycgOiB0aGlzO1xuICAgIH1cblxuICAgIGlmICh2ID09PSB1bmRlZmluZWQpIHtcbiAgICAgIGlmICghdGhpcy5fcGFydHMudXNlcm5hbWUpIHtcbiAgICAgICAgcmV0dXJuICcnO1xuICAgICAgfVxuXG4gICAgICB2YXIgdCA9IFVSSS5idWlsZFVzZXJpbmZvKHRoaXMuX3BhcnRzKTtcbiAgICAgIHJldHVybiB0LnN1YnN0cmluZygwLCB0Lmxlbmd0aCAtMSk7XG4gICAgfSBlbHNlIHtcbiAgICAgIGlmICh2W3YubGVuZ3RoLTFdICE9PSAnQCcpIHtcbiAgICAgICAgdiArPSAnQCc7XG4gICAgICB9XG5cbiAgICAgIFVSSS5wYXJzZVVzZXJpbmZvKHYsIHRoaXMuX3BhcnRzKTtcbiAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgIHJldHVybiB0aGlzO1xuICAgIH1cbiAgfTtcbiAgcC5yZXNvdXJjZSA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgdmFyIHBhcnRzO1xuXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgcmV0dXJuIHRoaXMucGF0aCgpICsgdGhpcy5zZWFyY2goKSArIHRoaXMuaGFzaCgpO1xuICAgIH1cblxuICAgIHBhcnRzID0gVVJJLnBhcnNlKHYpO1xuICAgIHRoaXMuX3BhcnRzLnBhdGggPSBwYXJ0cy5wYXRoO1xuICAgIHRoaXMuX3BhcnRzLnF1ZXJ5ID0gcGFydHMucXVlcnk7XG4gICAgdGhpcy5fcGFydHMuZnJhZ21lbnQgPSBwYXJ0cy5mcmFnbWVudDtcbiAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG5cbiAgLy8gZnJhY3Rpb24gYWNjZXNzb3JzXG4gIHAuc3ViZG9tYWluID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodGhpcy5fcGFydHMudXJuKSB7XG4gICAgICByZXR1cm4gdiA9PT0gdW5kZWZpbmVkID8gJycgOiB0aGlzO1xuICAgIH1cblxuICAgIC8vIGNvbnZlbmllbmNlLCByZXR1cm4gXCJ3d3dcIiBmcm9tIFwid3d3LmV4YW1wbGUub3JnXCJcbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICBpZiAoIXRoaXMuX3BhcnRzLmhvc3RuYW1lIHx8IHRoaXMuaXMoJ0lQJykpIHtcbiAgICAgICAgcmV0dXJuICcnO1xuICAgICAgfVxuXG4gICAgICAvLyBncmFiIGRvbWFpbiBhbmQgYWRkIGFub3RoZXIgc2VnbWVudFxuICAgICAgdmFyIGVuZCA9IHRoaXMuX3BhcnRzLmhvc3RuYW1lLmxlbmd0aCAtIHRoaXMuZG9tYWluKCkubGVuZ3RoIC0gMTtcbiAgICAgIHJldHVybiB0aGlzLl9wYXJ0cy5ob3N0bmFtZS5zdWJzdHJpbmcoMCwgZW5kKSB8fCAnJztcbiAgICB9IGVsc2Uge1xuICAgICAgdmFyIGUgPSB0aGlzLl9wYXJ0cy5ob3N0bmFtZS5sZW5ndGggLSB0aGlzLmRvbWFpbigpLmxlbmd0aDtcbiAgICAgIHZhciBzdWIgPSB0aGlzLl9wYXJ0cy5ob3N0bmFtZS5zdWJzdHJpbmcoMCwgZSk7XG4gICAgICB2YXIgcmVwbGFjZSA9IG5ldyBSZWdFeHAoJ14nICsgZXNjYXBlUmVnRXgoc3ViKSk7XG5cbiAgICAgIGlmICh2ICYmIHYuY2hhckF0KHYubGVuZ3RoIC0gMSkgIT09ICcuJykge1xuICAgICAgICB2ICs9ICcuJztcbiAgICAgIH1cblxuICAgICAgaWYgKHYpIHtcbiAgICAgICAgVVJJLmVuc3VyZVZhbGlkSG9zdG5hbWUodik7XG4gICAgICB9XG5cbiAgICAgIHRoaXMuX3BhcnRzLmhvc3RuYW1lID0gdGhpcy5fcGFydHMuaG9zdG5hbWUucmVwbGFjZShyZXBsYWNlLCB2KTtcbiAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgIHJldHVybiB0aGlzO1xuICAgIH1cbiAgfTtcbiAgcC5kb21haW4gPSBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgIHJldHVybiB2ID09PSB1bmRlZmluZWQgPyAnJyA6IHRoaXM7XG4gICAgfVxuXG4gICAgaWYgKHR5cGVvZiB2ID09PSAnYm9vbGVhbicpIHtcbiAgICAgIGJ1aWxkID0gdjtcbiAgICAgIHYgPSB1bmRlZmluZWQ7XG4gICAgfVxuXG4gICAgLy8gY29udmVuaWVuY2UsIHJldHVybiBcImV4YW1wbGUub3JnXCIgZnJvbSBcInd3dy5leGFtcGxlLm9yZ1wiXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgaWYgKCF0aGlzLl9wYXJ0cy5ob3N0bmFtZSB8fCB0aGlzLmlzKCdJUCcpKSB7XG4gICAgICAgIHJldHVybiAnJztcbiAgICAgIH1cblxuICAgICAgLy8gaWYgaG9zdG5hbWUgY29uc2lzdHMgb2YgMSBvciAyIHNlZ21lbnRzLCBpdCBtdXN0IGJlIHRoZSBkb21haW5cbiAgICAgIHZhciB0ID0gdGhpcy5fcGFydHMuaG9zdG5hbWUubWF0Y2goL1xcLi9nKTtcbiAgICAgIGlmICh0ICYmIHQubGVuZ3RoIDwgMikge1xuICAgICAgICByZXR1cm4gdGhpcy5fcGFydHMuaG9zdG5hbWU7XG4gICAgICB9XG5cbiAgICAgIC8vIGdyYWIgdGxkIGFuZCBhZGQgYW5vdGhlciBzZWdtZW50XG4gICAgICB2YXIgZW5kID0gdGhpcy5fcGFydHMuaG9zdG5hbWUubGVuZ3RoIC0gdGhpcy50bGQoYnVpbGQpLmxlbmd0aCAtIDE7XG4gICAgICBlbmQgPSB0aGlzLl9wYXJ0cy5ob3N0bmFtZS5sYXN0SW5kZXhPZignLicsIGVuZCAtMSkgKyAxO1xuICAgICAgcmV0dXJuIHRoaXMuX3BhcnRzLmhvc3RuYW1lLnN1YnN0cmluZyhlbmQpIHx8ICcnO1xuICAgIH0gZWxzZSB7XG4gICAgICBpZiAoIXYpIHtcbiAgICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignY2Fubm90IHNldCBkb21haW4gZW1wdHknKTtcbiAgICAgIH1cblxuICAgICAgVVJJLmVuc3VyZVZhbGlkSG9zdG5hbWUodik7XG5cbiAgICAgIGlmICghdGhpcy5fcGFydHMuaG9zdG5hbWUgfHwgdGhpcy5pcygnSVAnKSkge1xuICAgICAgICB0aGlzLl9wYXJ0cy5ob3N0bmFtZSA9IHY7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB2YXIgcmVwbGFjZSA9IG5ldyBSZWdFeHAoZXNjYXBlUmVnRXgodGhpcy5kb21haW4oKSkgKyAnJCcpO1xuICAgICAgICB0aGlzLl9wYXJ0cy5ob3N0bmFtZSA9IHRoaXMuX3BhcnRzLmhvc3RuYW1lLnJlcGxhY2UocmVwbGFjZSwgdik7XG4gICAgICB9XG5cbiAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgIHJldHVybiB0aGlzO1xuICAgIH1cbiAgfTtcbiAgcC50bGQgPSBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgIHJldHVybiB2ID09PSB1bmRlZmluZWQgPyAnJyA6IHRoaXM7XG4gICAgfVxuXG4gICAgaWYgKHR5cGVvZiB2ID09PSAnYm9vbGVhbicpIHtcbiAgICAgIGJ1aWxkID0gdjtcbiAgICAgIHYgPSB1bmRlZmluZWQ7XG4gICAgfVxuXG4gICAgLy8gcmV0dXJuIFwib3JnXCIgZnJvbSBcInd3dy5leGFtcGxlLm9yZ1wiXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgaWYgKCF0aGlzLl9wYXJ0cy5ob3N0bmFtZSB8fCB0aGlzLmlzKCdJUCcpKSB7XG4gICAgICAgIHJldHVybiAnJztcbiAgICAgIH1cblxuICAgICAgdmFyIHBvcyA9IHRoaXMuX3BhcnRzLmhvc3RuYW1lLmxhc3RJbmRleE9mKCcuJyk7XG4gICAgICB2YXIgdGxkID0gdGhpcy5fcGFydHMuaG9zdG5hbWUuc3Vic3RyaW5nKHBvcyArIDEpO1xuXG4gICAgICBpZiAoYnVpbGQgIT09IHRydWUgJiYgU0xEICYmIFNMRC5saXN0W3RsZC50b0xvd2VyQ2FzZSgpXSkge1xuICAgICAgICByZXR1cm4gU0xELmdldCh0aGlzLl9wYXJ0cy5ob3N0bmFtZSkgfHwgdGxkO1xuICAgICAgfVxuXG4gICAgICByZXR1cm4gdGxkO1xuICAgIH0gZWxzZSB7XG4gICAgICB2YXIgcmVwbGFjZTtcblxuICAgICAgaWYgKCF2KSB7XG4gICAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ2Nhbm5vdCBzZXQgVExEIGVtcHR5Jyk7XG4gICAgICB9IGVsc2UgaWYgKHYubWF0Y2goL1teYS16QS1aMC05LV0vKSkge1xuICAgICAgICBpZiAoU0xEICYmIFNMRC5pcyh2KSkge1xuICAgICAgICAgIHJlcGxhY2UgPSBuZXcgUmVnRXhwKGVzY2FwZVJlZ0V4KHRoaXMudGxkKCkpICsgJyQnKTtcbiAgICAgICAgICB0aGlzLl9wYXJ0cy5ob3N0bmFtZSA9IHRoaXMuX3BhcnRzLmhvc3RuYW1lLnJlcGxhY2UocmVwbGFjZSwgdik7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignVExEIFwiJyArIHYgKyAnXCIgY29udGFpbnMgY2hhcmFjdGVycyBvdGhlciB0aGFuIFtBLVowLTldJyk7XG4gICAgICAgIH1cbiAgICAgIH0gZWxzZSBpZiAoIXRoaXMuX3BhcnRzLmhvc3RuYW1lIHx8IHRoaXMuaXMoJ0lQJykpIHtcbiAgICAgICAgdGhyb3cgbmV3IFJlZmVyZW5jZUVycm9yKCdjYW5ub3Qgc2V0IFRMRCBvbiBub24tZG9tYWluIGhvc3QnKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJlcGxhY2UgPSBuZXcgUmVnRXhwKGVzY2FwZVJlZ0V4KHRoaXMudGxkKCkpICsgJyQnKTtcbiAgICAgICAgdGhpcy5fcGFydHMuaG9zdG5hbWUgPSB0aGlzLl9wYXJ0cy5ob3N0bmFtZS5yZXBsYWNlKHJlcGxhY2UsIHYpO1xuICAgICAgfVxuXG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG4gIH07XG4gIHAuZGlyZWN0b3J5ID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodGhpcy5fcGFydHMudXJuKSB7XG4gICAgICByZXR1cm4gdiA9PT0gdW5kZWZpbmVkID8gJycgOiB0aGlzO1xuICAgIH1cblxuICAgIGlmICh2ID09PSB1bmRlZmluZWQgfHwgdiA9PT0gdHJ1ZSkge1xuICAgICAgaWYgKCF0aGlzLl9wYXJ0cy5wYXRoICYmICF0aGlzLl9wYXJ0cy5ob3N0bmFtZSkge1xuICAgICAgICByZXR1cm4gJyc7XG4gICAgICB9XG5cbiAgICAgIGlmICh0aGlzLl9wYXJ0cy5wYXRoID09PSAnLycpIHtcbiAgICAgICAgcmV0dXJuICcvJztcbiAgICAgIH1cblxuICAgICAgdmFyIGVuZCA9IHRoaXMuX3BhcnRzLnBhdGgubGVuZ3RoIC0gdGhpcy5maWxlbmFtZSgpLmxlbmd0aCAtIDE7XG4gICAgICB2YXIgcmVzID0gdGhpcy5fcGFydHMucGF0aC5zdWJzdHJpbmcoMCwgZW5kKSB8fCAodGhpcy5fcGFydHMuaG9zdG5hbWUgPyAnLycgOiAnJyk7XG5cbiAgICAgIHJldHVybiB2ID8gVVJJLmRlY29kZVBhdGgocmVzKSA6IHJlcztcblxuICAgIH0gZWxzZSB7XG4gICAgICB2YXIgZSA9IHRoaXMuX3BhcnRzLnBhdGgubGVuZ3RoIC0gdGhpcy5maWxlbmFtZSgpLmxlbmd0aDtcbiAgICAgIHZhciBkaXJlY3RvcnkgPSB0aGlzLl9wYXJ0cy5wYXRoLnN1YnN0cmluZygwLCBlKTtcbiAgICAgIHZhciByZXBsYWNlID0gbmV3IFJlZ0V4cCgnXicgKyBlc2NhcGVSZWdFeChkaXJlY3RvcnkpKTtcblxuICAgICAgLy8gZnVsbHkgcXVhbGlmaWVyIGRpcmVjdG9yaWVzIGJlZ2luIHdpdGggYSBzbGFzaFxuICAgICAgaWYgKCF0aGlzLmlzKCdyZWxhdGl2ZScpKSB7XG4gICAgICAgIGlmICghdikge1xuICAgICAgICAgIHYgPSAnLyc7XG4gICAgICAgIH1cblxuICAgICAgICBpZiAodi5jaGFyQXQoMCkgIT09ICcvJykge1xuICAgICAgICAgIHYgPSAnLycgKyB2O1xuICAgICAgICB9XG4gICAgICB9XG5cbiAgICAgIC8vIGRpcmVjdG9yaWVzIGFsd2F5cyBlbmQgd2l0aCBhIHNsYXNoXG4gICAgICBpZiAodiAmJiB2LmNoYXJBdCh2Lmxlbmd0aCAtIDEpICE9PSAnLycpIHtcbiAgICAgICAgdiArPSAnLyc7XG4gICAgICB9XG5cbiAgICAgIHYgPSBVUkkucmVjb2RlUGF0aCh2KTtcbiAgICAgIHRoaXMuX3BhcnRzLnBhdGggPSB0aGlzLl9wYXJ0cy5wYXRoLnJlcGxhY2UocmVwbGFjZSwgdik7XG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG4gIH07XG4gIHAuZmlsZW5hbWUgPSBmdW5jdGlvbih2LCBidWlsZCkge1xuICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgIHJldHVybiB2ID09PSB1bmRlZmluZWQgPyAnJyA6IHRoaXM7XG4gICAgfVxuXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCB8fCB2ID09PSB0cnVlKSB7XG4gICAgICBpZiAoIXRoaXMuX3BhcnRzLnBhdGggfHwgdGhpcy5fcGFydHMucGF0aCA9PT0gJy8nKSB7XG4gICAgICAgIHJldHVybiAnJztcbiAgICAgIH1cblxuICAgICAgdmFyIHBvcyA9IHRoaXMuX3BhcnRzLnBhdGgubGFzdEluZGV4T2YoJy8nKTtcbiAgICAgIHZhciByZXMgPSB0aGlzLl9wYXJ0cy5wYXRoLnN1YnN0cmluZyhwb3MrMSk7XG5cbiAgICAgIHJldHVybiB2ID8gVVJJLmRlY29kZVBhdGhTZWdtZW50KHJlcykgOiByZXM7XG4gICAgfSBlbHNlIHtcbiAgICAgIHZhciBtdXRhdGVkRGlyZWN0b3J5ID0gZmFsc2U7XG5cbiAgICAgIGlmICh2LmNoYXJBdCgwKSA9PT0gJy8nKSB7XG4gICAgICAgIHYgPSB2LnN1YnN0cmluZygxKTtcbiAgICAgIH1cblxuICAgICAgaWYgKHYubWF0Y2goL1xcLj9cXC8vKSkge1xuICAgICAgICBtdXRhdGVkRGlyZWN0b3J5ID0gdHJ1ZTtcbiAgICAgIH1cblxuICAgICAgdmFyIHJlcGxhY2UgPSBuZXcgUmVnRXhwKGVzY2FwZVJlZ0V4KHRoaXMuZmlsZW5hbWUoKSkgKyAnJCcpO1xuICAgICAgdiA9IFVSSS5yZWNvZGVQYXRoKHYpO1xuICAgICAgdGhpcy5fcGFydHMucGF0aCA9IHRoaXMuX3BhcnRzLnBhdGgucmVwbGFjZShyZXBsYWNlLCB2KTtcblxuICAgICAgaWYgKG11dGF0ZWREaXJlY3RvcnkpIHtcbiAgICAgICAgdGhpcy5ub3JtYWxpemVQYXRoKGJ1aWxkKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICAgIH1cblxuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfVxuICB9O1xuICBwLnN1ZmZpeCA9IGZ1bmN0aW9uKHYsIGJ1aWxkKSB7XG4gICAgaWYgKHRoaXMuX3BhcnRzLnVybikge1xuICAgICAgcmV0dXJuIHYgPT09IHVuZGVmaW5lZCA/ICcnIDogdGhpcztcbiAgICB9XG5cbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkIHx8IHYgPT09IHRydWUpIHtcbiAgICAgIGlmICghdGhpcy5fcGFydHMucGF0aCB8fCB0aGlzLl9wYXJ0cy5wYXRoID09PSAnLycpIHtcbiAgICAgICAgcmV0dXJuICcnO1xuICAgICAgfVxuXG4gICAgICB2YXIgZmlsZW5hbWUgPSB0aGlzLmZpbGVuYW1lKCk7XG4gICAgICB2YXIgcG9zID0gZmlsZW5hbWUubGFzdEluZGV4T2YoJy4nKTtcbiAgICAgIHZhciBzLCByZXM7XG5cbiAgICAgIGlmIChwb3MgPT09IC0xKSB7XG4gICAgICAgIHJldHVybiAnJztcbiAgICAgIH1cblxuICAgICAgLy8gc3VmZml4IG1heSBvbmx5IGNvbnRhaW4gYWxudW0gY2hhcmFjdGVycyAoeXVwLCBJIG1hZGUgdGhpcyB1cC4pXG4gICAgICBzID0gZmlsZW5hbWUuc3Vic3RyaW5nKHBvcysxKTtcbiAgICAgIHJlcyA9ICgvXlthLXowLTklXSskL2kpLnRlc3QocykgPyBzIDogJyc7XG4gICAgICByZXR1cm4gdiA/IFVSSS5kZWNvZGVQYXRoU2VnbWVudChyZXMpIDogcmVzO1xuICAgIH0gZWxzZSB7XG4gICAgICBpZiAodi5jaGFyQXQoMCkgPT09ICcuJykge1xuICAgICAgICB2ID0gdi5zdWJzdHJpbmcoMSk7XG4gICAgICB9XG5cbiAgICAgIHZhciBzdWZmaXggPSB0aGlzLnN1ZmZpeCgpO1xuICAgICAgdmFyIHJlcGxhY2U7XG5cbiAgICAgIGlmICghc3VmZml4KSB7XG4gICAgICAgIGlmICghdikge1xuICAgICAgICAgIHJldHVybiB0aGlzO1xuICAgICAgICB9XG5cbiAgICAgICAgdGhpcy5fcGFydHMucGF0aCArPSAnLicgKyBVUkkucmVjb2RlUGF0aCh2KTtcbiAgICAgIH0gZWxzZSBpZiAoIXYpIHtcbiAgICAgICAgcmVwbGFjZSA9IG5ldyBSZWdFeHAoZXNjYXBlUmVnRXgoJy4nICsgc3VmZml4KSArICckJyk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICByZXBsYWNlID0gbmV3IFJlZ0V4cChlc2NhcGVSZWdFeChzdWZmaXgpICsgJyQnKTtcbiAgICAgIH1cblxuICAgICAgaWYgKHJlcGxhY2UpIHtcbiAgICAgICAgdiA9IFVSSS5yZWNvZGVQYXRoKHYpO1xuICAgICAgICB0aGlzLl9wYXJ0cy5wYXRoID0gdGhpcy5fcGFydHMucGF0aC5yZXBsYWNlKHJlcGxhY2UsIHYpO1xuICAgICAgfVxuXG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG4gIH07XG4gIHAuc2VnbWVudCA9IGZ1bmN0aW9uKHNlZ21lbnQsIHYsIGJ1aWxkKSB7XG4gICAgdmFyIHNlcGFyYXRvciA9IHRoaXMuX3BhcnRzLnVybiA/ICc6JyA6ICcvJztcbiAgICB2YXIgcGF0aCA9IHRoaXMucGF0aCgpO1xuICAgIHZhciBhYnNvbHV0ZSA9IHBhdGguc3Vic3RyaW5nKDAsIDEpID09PSAnLyc7XG4gICAgdmFyIHNlZ21lbnRzID0gcGF0aC5zcGxpdChzZXBhcmF0b3IpO1xuXG4gICAgaWYgKHNlZ21lbnQgIT09IHVuZGVmaW5lZCAmJiB0eXBlb2Ygc2VnbWVudCAhPT0gJ251bWJlcicpIHtcbiAgICAgIGJ1aWxkID0gdjtcbiAgICAgIHYgPSBzZWdtZW50O1xuICAgICAgc2VnbWVudCA9IHVuZGVmaW5lZDtcbiAgICB9XG5cbiAgICBpZiAoc2VnbWVudCAhPT0gdW5kZWZpbmVkICYmIHR5cGVvZiBzZWdtZW50ICE9PSAnbnVtYmVyJykge1xuICAgICAgdGhyb3cgbmV3IEVycm9yKCdCYWQgc2VnbWVudCBcIicgKyBzZWdtZW50ICsgJ1wiLCBtdXN0IGJlIDAtYmFzZWQgaW50ZWdlcicpO1xuICAgIH1cblxuICAgIGlmIChhYnNvbHV0ZSkge1xuICAgICAgc2VnbWVudHMuc2hpZnQoKTtcbiAgICB9XG5cbiAgICBpZiAoc2VnbWVudCA8IDApIHtcbiAgICAgIC8vIGFsbG93IG5lZ2F0aXZlIGluZGV4ZXMgdG8gYWRkcmVzcyBmcm9tIHRoZSBlbmRcbiAgICAgIHNlZ21lbnQgPSBNYXRoLm1heChzZWdtZW50cy5sZW5ndGggKyBzZWdtZW50LCAwKTtcbiAgICB9XG5cbiAgICBpZiAodiA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICAvKmpzaGludCBsYXhicmVhazogdHJ1ZSAqL1xuICAgICAgcmV0dXJuIHNlZ21lbnQgPT09IHVuZGVmaW5lZFxuICAgICAgICA/IHNlZ21lbnRzXG4gICAgICAgIDogc2VnbWVudHNbc2VnbWVudF07XG4gICAgICAvKmpzaGludCBsYXhicmVhazogZmFsc2UgKi9cbiAgICB9IGVsc2UgaWYgKHNlZ21lbnQgPT09IG51bGwgfHwgc2VnbWVudHNbc2VnbWVudF0gPT09IHVuZGVmaW5lZCkge1xuICAgICAgaWYgKGlzQXJyYXkodikpIHtcbiAgICAgICAgc2VnbWVudHMgPSBbXTtcbiAgICAgICAgLy8gY29sbGFwc2UgZW1wdHkgZWxlbWVudHMgd2l0aGluIGFycmF5XG4gICAgICAgIGZvciAodmFyIGk9MCwgbD12Lmxlbmd0aDsgaSA8IGw7IGkrKykge1xuICAgICAgICAgIGlmICghdltpXS5sZW5ndGggJiYgKCFzZWdtZW50cy5sZW5ndGggfHwgIXNlZ21lbnRzW3NlZ21lbnRzLmxlbmd0aCAtMV0ubGVuZ3RoKSkge1xuICAgICAgICAgICAgY29udGludWU7XG4gICAgICAgICAgfVxuXG4gICAgICAgICAgaWYgKHNlZ21lbnRzLmxlbmd0aCAmJiAhc2VnbWVudHNbc2VnbWVudHMubGVuZ3RoIC0xXS5sZW5ndGgpIHtcbiAgICAgICAgICAgIHNlZ21lbnRzLnBvcCgpO1xuICAgICAgICAgIH1cblxuICAgICAgICAgIHNlZ21lbnRzLnB1c2godHJpbVNsYXNoZXModltpXSkpO1xuICAgICAgICB9XG4gICAgICB9IGVsc2UgaWYgKHYgfHwgdHlwZW9mIHYgPT09ICdzdHJpbmcnKSB7XG4gICAgICAgIHYgPSB0cmltU2xhc2hlcyh2KTtcbiAgICAgICAgaWYgKHNlZ21lbnRzW3NlZ21lbnRzLmxlbmd0aCAtMV0gPT09ICcnKSB7XG4gICAgICAgICAgLy8gZW1wdHkgdHJhaWxpbmcgZWxlbWVudHMgaGF2ZSB0byBiZSBvdmVyd3JpdHRlblxuICAgICAgICAgIC8vIHRvIHByZXZlbnQgcmVzdWx0cyBzdWNoIGFzIC9mb28vL2JhclxuICAgICAgICAgIHNlZ21lbnRzW3NlZ21lbnRzLmxlbmd0aCAtMV0gPSB2O1xuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgIHNlZ21lbnRzLnB1c2godik7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9IGVsc2Uge1xuICAgICAgaWYgKHYpIHtcbiAgICAgICAgc2VnbWVudHNbc2VnbWVudF0gPSB0cmltU2xhc2hlcyh2KTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHNlZ21lbnRzLnNwbGljZShzZWdtZW50LCAxKTtcbiAgICAgIH1cbiAgICB9XG5cbiAgICBpZiAoYWJzb2x1dGUpIHtcbiAgICAgIHNlZ21lbnRzLnVuc2hpZnQoJycpO1xuICAgIH1cblxuICAgIHJldHVybiB0aGlzLnBhdGgoc2VnbWVudHMuam9pbihzZXBhcmF0b3IpLCBidWlsZCk7XG4gIH07XG4gIHAuc2VnbWVudENvZGVkID0gZnVuY3Rpb24oc2VnbWVudCwgdiwgYnVpbGQpIHtcbiAgICB2YXIgc2VnbWVudHMsIGksIGw7XG5cbiAgICBpZiAodHlwZW9mIHNlZ21lbnQgIT09ICdudW1iZXInKSB7XG4gICAgICBidWlsZCA9IHY7XG4gICAgICB2ID0gc2VnbWVudDtcbiAgICAgIHNlZ21lbnQgPSB1bmRlZmluZWQ7XG4gICAgfVxuXG4gICAgaWYgKHYgPT09IHVuZGVmaW5lZCkge1xuICAgICAgc2VnbWVudHMgPSB0aGlzLnNlZ21lbnQoc2VnbWVudCwgdiwgYnVpbGQpO1xuICAgICAgaWYgKCFpc0FycmF5KHNlZ21lbnRzKSkge1xuICAgICAgICBzZWdtZW50cyA9IHNlZ21lbnRzICE9PSB1bmRlZmluZWQgPyBVUkkuZGVjb2RlKHNlZ21lbnRzKSA6IHVuZGVmaW5lZDtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGZvciAoaSA9IDAsIGwgPSBzZWdtZW50cy5sZW5ndGg7IGkgPCBsOyBpKyspIHtcbiAgICAgICAgICBzZWdtZW50c1tpXSA9IFVSSS5kZWNvZGUoc2VnbWVudHNbaV0pO1xuICAgICAgICB9XG4gICAgICB9XG5cbiAgICAgIHJldHVybiBzZWdtZW50cztcbiAgICB9XG5cbiAgICBpZiAoIWlzQXJyYXkodikpIHtcbiAgICAgIHYgPSAodHlwZW9mIHYgPT09ICdzdHJpbmcnIHx8IHYgaW5zdGFuY2VvZiBTdHJpbmcpID8gVVJJLmVuY29kZSh2KSA6IHY7XG4gICAgfSBlbHNlIHtcbiAgICAgIGZvciAoaSA9IDAsIGwgPSB2Lmxlbmd0aDsgaSA8IGw7IGkrKykge1xuICAgICAgICB2W2ldID0gVVJJLmVuY29kZSh2W2ldKTtcbiAgICAgIH1cbiAgICB9XG5cbiAgICByZXR1cm4gdGhpcy5zZWdtZW50KHNlZ21lbnQsIHYsIGJ1aWxkKTtcbiAgfTtcblxuICAvLyBtdXRhdGluZyBxdWVyeSBzdHJpbmdcbiAgdmFyIHEgPSBwLnF1ZXJ5O1xuICBwLnF1ZXJ5ID0gZnVuY3Rpb24odiwgYnVpbGQpIHtcbiAgICBpZiAodiA9PT0gdHJ1ZSkge1xuICAgICAgcmV0dXJuIFVSSS5wYXJzZVF1ZXJ5KHRoaXMuX3BhcnRzLnF1ZXJ5LCB0aGlzLl9wYXJ0cy5lc2NhcGVRdWVyeVNwYWNlKTtcbiAgICB9IGVsc2UgaWYgKHR5cGVvZiB2ID09PSAnZnVuY3Rpb24nKSB7XG4gICAgICB2YXIgZGF0YSA9IFVSSS5wYXJzZVF1ZXJ5KHRoaXMuX3BhcnRzLnF1ZXJ5LCB0aGlzLl9wYXJ0cy5lc2NhcGVRdWVyeVNwYWNlKTtcbiAgICAgIHZhciByZXN1bHQgPSB2LmNhbGwodGhpcywgZGF0YSk7XG4gICAgICB0aGlzLl9wYXJ0cy5xdWVyeSA9IFVSSS5idWlsZFF1ZXJ5KHJlc3VsdCB8fCBkYXRhLCB0aGlzLl9wYXJ0cy5kdXBsaWNhdGVRdWVyeVBhcmFtZXRlcnMsIHRoaXMuX3BhcnRzLmVzY2FwZVF1ZXJ5U3BhY2UpO1xuICAgICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgICAgcmV0dXJuIHRoaXM7XG4gICAgfSBlbHNlIGlmICh2ICE9PSB1bmRlZmluZWQgJiYgdHlwZW9mIHYgIT09ICdzdHJpbmcnKSB7XG4gICAgICB0aGlzLl9wYXJ0cy5xdWVyeSA9IFVSSS5idWlsZFF1ZXJ5KHYsIHRoaXMuX3BhcnRzLmR1cGxpY2F0ZVF1ZXJ5UGFyYW1ldGVycywgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSk7XG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9IGVsc2Uge1xuICAgICAgcmV0dXJuIHEuY2FsbCh0aGlzLCB2LCBidWlsZCk7XG4gICAgfVxuICB9O1xuICBwLnNldFF1ZXJ5ID0gZnVuY3Rpb24obmFtZSwgdmFsdWUsIGJ1aWxkKSB7XG4gICAgdmFyIGRhdGEgPSBVUkkucGFyc2VRdWVyeSh0aGlzLl9wYXJ0cy5xdWVyeSwgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSk7XG5cbiAgICBpZiAodHlwZW9mIG5hbWUgPT09ICdzdHJpbmcnIHx8IG5hbWUgaW5zdGFuY2VvZiBTdHJpbmcpIHtcbiAgICAgIGRhdGFbbmFtZV0gPSB2YWx1ZSAhPT0gdW5kZWZpbmVkID8gdmFsdWUgOiBudWxsO1xuICAgIH0gZWxzZSBpZiAodHlwZW9mIG5hbWUgPT09ICdvYmplY3QnKSB7XG4gICAgICBmb3IgKHZhciBrZXkgaW4gbmFtZSkge1xuICAgICAgICBpZiAoaGFzT3duLmNhbGwobmFtZSwga2V5KSkge1xuICAgICAgICAgIGRhdGFba2V5XSA9IG5hbWVba2V5XTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH0gZWxzZSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdVUkkuYWRkUXVlcnkoKSBhY2NlcHRzIGFuIG9iamVjdCwgc3RyaW5nIGFzIHRoZSBuYW1lIHBhcmFtZXRlcicpO1xuICAgIH1cblxuICAgIHRoaXMuX3BhcnRzLnF1ZXJ5ID0gVVJJLmJ1aWxkUXVlcnkoZGF0YSwgdGhpcy5fcGFydHMuZHVwbGljYXRlUXVlcnlQYXJhbWV0ZXJzLCB0aGlzLl9wYXJ0cy5lc2NhcGVRdWVyeVNwYWNlKTtcbiAgICBpZiAodHlwZW9mIG5hbWUgIT09ICdzdHJpbmcnKSB7XG4gICAgICBidWlsZCA9IHZhbHVlO1xuICAgIH1cblxuICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICByZXR1cm4gdGhpcztcbiAgfTtcbiAgcC5hZGRRdWVyeSA9IGZ1bmN0aW9uKG5hbWUsIHZhbHVlLCBidWlsZCkge1xuICAgIHZhciBkYXRhID0gVVJJLnBhcnNlUXVlcnkodGhpcy5fcGFydHMucXVlcnksIHRoaXMuX3BhcnRzLmVzY2FwZVF1ZXJ5U3BhY2UpO1xuICAgIFVSSS5hZGRRdWVyeShkYXRhLCBuYW1lLCB2YWx1ZSA9PT0gdW5kZWZpbmVkID8gbnVsbCA6IHZhbHVlKTtcbiAgICB0aGlzLl9wYXJ0cy5xdWVyeSA9IFVSSS5idWlsZFF1ZXJ5KGRhdGEsIHRoaXMuX3BhcnRzLmR1cGxpY2F0ZVF1ZXJ5UGFyYW1ldGVycywgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSk7XG4gICAgaWYgKHR5cGVvZiBuYW1lICE9PSAnc3RyaW5nJykge1xuICAgICAgYnVpbGQgPSB2YWx1ZTtcbiAgICB9XG5cbiAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG4gIHAucmVtb3ZlUXVlcnkgPSBmdW5jdGlvbihuYW1lLCB2YWx1ZSwgYnVpbGQpIHtcbiAgICB2YXIgZGF0YSA9IFVSSS5wYXJzZVF1ZXJ5KHRoaXMuX3BhcnRzLnF1ZXJ5LCB0aGlzLl9wYXJ0cy5lc2NhcGVRdWVyeVNwYWNlKTtcbiAgICBVUkkucmVtb3ZlUXVlcnkoZGF0YSwgbmFtZSwgdmFsdWUpO1xuICAgIHRoaXMuX3BhcnRzLnF1ZXJ5ID0gVVJJLmJ1aWxkUXVlcnkoZGF0YSwgdGhpcy5fcGFydHMuZHVwbGljYXRlUXVlcnlQYXJhbWV0ZXJzLCB0aGlzLl9wYXJ0cy5lc2NhcGVRdWVyeVNwYWNlKTtcbiAgICBpZiAodHlwZW9mIG5hbWUgIT09ICdzdHJpbmcnKSB7XG4gICAgICBidWlsZCA9IHZhbHVlO1xuICAgIH1cblxuICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICByZXR1cm4gdGhpcztcbiAgfTtcbiAgcC5oYXNRdWVyeSA9IGZ1bmN0aW9uKG5hbWUsIHZhbHVlLCB3aXRoaW5BcnJheSkge1xuICAgIHZhciBkYXRhID0gVVJJLnBhcnNlUXVlcnkodGhpcy5fcGFydHMucXVlcnksIHRoaXMuX3BhcnRzLmVzY2FwZVF1ZXJ5U3BhY2UpO1xuICAgIHJldHVybiBVUkkuaGFzUXVlcnkoZGF0YSwgbmFtZSwgdmFsdWUsIHdpdGhpbkFycmF5KTtcbiAgfTtcbiAgcC5zZXRTZWFyY2ggPSBwLnNldFF1ZXJ5O1xuICBwLmFkZFNlYXJjaCA9IHAuYWRkUXVlcnk7XG4gIHAucmVtb3ZlU2VhcmNoID0gcC5yZW1vdmVRdWVyeTtcbiAgcC5oYXNTZWFyY2ggPSBwLmhhc1F1ZXJ5O1xuXG4gIC8vIHNhbml0aXppbmcgVVJMc1xuICBwLm5vcm1hbGl6ZSA9IGZ1bmN0aW9uKCkge1xuICAgIGlmICh0aGlzLl9wYXJ0cy51cm4pIHtcbiAgICAgIHJldHVybiB0aGlzXG4gICAgICAgIC5ub3JtYWxpemVQcm90b2NvbChmYWxzZSlcbiAgICAgICAgLm5vcm1hbGl6ZVBhdGgoZmFsc2UpXG4gICAgICAgIC5ub3JtYWxpemVRdWVyeShmYWxzZSlcbiAgICAgICAgLm5vcm1hbGl6ZUZyYWdtZW50KGZhbHNlKVxuICAgICAgICAuYnVpbGQoKTtcbiAgICB9XG5cbiAgICByZXR1cm4gdGhpc1xuICAgICAgLm5vcm1hbGl6ZVByb3RvY29sKGZhbHNlKVxuICAgICAgLm5vcm1hbGl6ZUhvc3RuYW1lKGZhbHNlKVxuICAgICAgLm5vcm1hbGl6ZVBvcnQoZmFsc2UpXG4gICAgICAubm9ybWFsaXplUGF0aChmYWxzZSlcbiAgICAgIC5ub3JtYWxpemVRdWVyeShmYWxzZSlcbiAgICAgIC5ub3JtYWxpemVGcmFnbWVudChmYWxzZSlcbiAgICAgIC5idWlsZCgpO1xuICB9O1xuICBwLm5vcm1hbGl6ZVByb3RvY29sID0gZnVuY3Rpb24oYnVpbGQpIHtcbiAgICBpZiAodHlwZW9mIHRoaXMuX3BhcnRzLnByb3RvY29sID09PSAnc3RyaW5nJykge1xuICAgICAgdGhpcy5fcGFydHMucHJvdG9jb2wgPSB0aGlzLl9wYXJ0cy5wcm90b2NvbC50b0xvd2VyQ2FzZSgpO1xuICAgICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgIH1cblxuICAgIHJldHVybiB0aGlzO1xuICB9O1xuICBwLm5vcm1hbGl6ZUhvc3RuYW1lID0gZnVuY3Rpb24oYnVpbGQpIHtcbiAgICBpZiAodGhpcy5fcGFydHMuaG9zdG5hbWUpIHtcbiAgICAgIGlmICh0aGlzLmlzKCdJRE4nKSAmJiBwdW55Y29kZSkge1xuICAgICAgICB0aGlzLl9wYXJ0cy5ob3N0bmFtZSA9IHB1bnljb2RlLnRvQVNDSUkodGhpcy5fcGFydHMuaG9zdG5hbWUpO1xuICAgICAgfSBlbHNlIGlmICh0aGlzLmlzKCdJUHY2JykgJiYgSVB2Nikge1xuICAgICAgICB0aGlzLl9wYXJ0cy5ob3N0bmFtZSA9IElQdjYuYmVzdCh0aGlzLl9wYXJ0cy5ob3N0bmFtZSk7XG4gICAgICB9XG5cbiAgICAgIHRoaXMuX3BhcnRzLmhvc3RuYW1lID0gdGhpcy5fcGFydHMuaG9zdG5hbWUudG9Mb3dlckNhc2UoKTtcbiAgICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICB9XG5cbiAgICByZXR1cm4gdGhpcztcbiAgfTtcbiAgcC5ub3JtYWxpemVQb3J0ID0gZnVuY3Rpb24oYnVpbGQpIHtcbiAgICAvLyByZW1vdmUgcG9ydCBvZiBpdCdzIHRoZSBwcm90b2NvbCdzIGRlZmF1bHRcbiAgICBpZiAodHlwZW9mIHRoaXMuX3BhcnRzLnByb3RvY29sID09PSAnc3RyaW5nJyAmJiB0aGlzLl9wYXJ0cy5wb3J0ID09PSBVUkkuZGVmYXVsdFBvcnRzW3RoaXMuX3BhcnRzLnByb3RvY29sXSkge1xuICAgICAgdGhpcy5fcGFydHMucG9ydCA9IG51bGw7XG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgfVxuXG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG4gIHAubm9ybWFsaXplUGF0aCA9IGZ1bmN0aW9uKGJ1aWxkKSB7XG4gICAgdmFyIF9wYXRoID0gdGhpcy5fcGFydHMucGF0aDtcbiAgICBpZiAoIV9wYXRoKSB7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG5cbiAgICBpZiAodGhpcy5fcGFydHMudXJuKSB7XG4gICAgICB0aGlzLl9wYXJ0cy5wYXRoID0gVVJJLnJlY29kZVVyblBhdGgodGhpcy5fcGFydHMucGF0aCk7XG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG5cbiAgICBpZiAodGhpcy5fcGFydHMucGF0aCA9PT0gJy8nKSB7XG4gICAgICByZXR1cm4gdGhpcztcbiAgICB9XG5cbiAgICB2YXIgX3dhc19yZWxhdGl2ZTtcbiAgICB2YXIgX2xlYWRpbmdQYXJlbnRzID0gJyc7XG4gICAgdmFyIF9wYXJlbnQsIF9wb3M7XG5cbiAgICAvLyBoYW5kbGUgcmVsYXRpdmUgcGF0aHNcbiAgICBpZiAoX3BhdGguY2hhckF0KDApICE9PSAnLycpIHtcbiAgICAgIF93YXNfcmVsYXRpdmUgPSB0cnVlO1xuICAgICAgX3BhdGggPSAnLycgKyBfcGF0aDtcbiAgICB9XG5cbiAgICAvLyBoYW5kbGUgcmVsYXRpdmUgZmlsZXMgKGFzIG9wcG9zZWQgdG8gZGlyZWN0b3JpZXMpXG4gICAgaWYgKF9wYXRoLnNsaWNlKC0zKSA9PT0gJy8uLicgfHwgX3BhdGguc2xpY2UoLTIpID09PSAnLy4nKSB7XG4gICAgICBfcGF0aCArPSAnLyc7XG4gICAgfVxuXG4gICAgLy8gcmVzb2x2ZSBzaW1wbGVzXG4gICAgX3BhdGggPSBfcGF0aFxuICAgICAgLnJlcGxhY2UoLyhcXC8oXFwuXFwvKSspfChcXC9cXC4kKS9nLCAnLycpXG4gICAgICAucmVwbGFjZSgvXFwvezIsfS9nLCAnLycpO1xuXG4gICAgLy8gcmVtZW1iZXIgbGVhZGluZyBwYXJlbnRzXG4gICAgaWYgKF93YXNfcmVsYXRpdmUpIHtcbiAgICAgIF9sZWFkaW5nUGFyZW50cyA9IF9wYXRoLnN1YnN0cmluZygxKS5tYXRjaCgvXihcXC5cXC5cXC8pKy8pIHx8ICcnO1xuICAgICAgaWYgKF9sZWFkaW5nUGFyZW50cykge1xuICAgICAgICBfbGVhZGluZ1BhcmVudHMgPSBfbGVhZGluZ1BhcmVudHNbMF07XG4gICAgICB9XG4gICAgfVxuXG4gICAgLy8gcmVzb2x2ZSBwYXJlbnRzXG4gICAgd2hpbGUgKHRydWUpIHtcbiAgICAgIF9wYXJlbnQgPSBfcGF0aC5pbmRleE9mKCcvLi4nKTtcbiAgICAgIGlmIChfcGFyZW50ID09PSAtMSkge1xuICAgICAgICAvLyBubyBtb3JlIC4uLyB0byByZXNvbHZlXG4gICAgICAgIGJyZWFrO1xuICAgICAgfSBlbHNlIGlmIChfcGFyZW50ID09PSAwKSB7XG4gICAgICAgIC8vIHRvcCBsZXZlbCBjYW5ub3QgYmUgcmVsYXRpdmUsIHNraXAgaXRcbiAgICAgICAgX3BhdGggPSBfcGF0aC5zdWJzdHJpbmcoMyk7XG4gICAgICAgIGNvbnRpbnVlO1xuICAgICAgfVxuXG4gICAgICBfcG9zID0gX3BhdGguc3Vic3RyaW5nKDAsIF9wYXJlbnQpLmxhc3RJbmRleE9mKCcvJyk7XG4gICAgICBpZiAoX3BvcyA9PT0gLTEpIHtcbiAgICAgICAgX3BvcyA9IF9wYXJlbnQ7XG4gICAgICB9XG4gICAgICBfcGF0aCA9IF9wYXRoLnN1YnN0cmluZygwLCBfcG9zKSArIF9wYXRoLnN1YnN0cmluZyhfcGFyZW50ICsgMyk7XG4gICAgfVxuXG4gICAgLy8gcmV2ZXJ0IHRvIHJlbGF0aXZlXG4gICAgaWYgKF93YXNfcmVsYXRpdmUgJiYgdGhpcy5pcygncmVsYXRpdmUnKSkge1xuICAgICAgX3BhdGggPSBfbGVhZGluZ1BhcmVudHMgKyBfcGF0aC5zdWJzdHJpbmcoMSk7XG4gICAgfVxuXG4gICAgX3BhdGggPSBVUkkucmVjb2RlUGF0aChfcGF0aCk7XG4gICAgdGhpcy5fcGFydHMucGF0aCA9IF9wYXRoO1xuICAgIHRoaXMuYnVpbGQoIWJ1aWxkKTtcbiAgICByZXR1cm4gdGhpcztcbiAgfTtcbiAgcC5ub3JtYWxpemVQYXRobmFtZSA9IHAubm9ybWFsaXplUGF0aDtcbiAgcC5ub3JtYWxpemVRdWVyeSA9IGZ1bmN0aW9uKGJ1aWxkKSB7XG4gICAgaWYgKHR5cGVvZiB0aGlzLl9wYXJ0cy5xdWVyeSA9PT0gJ3N0cmluZycpIHtcbiAgICAgIGlmICghdGhpcy5fcGFydHMucXVlcnkubGVuZ3RoKSB7XG4gICAgICAgIHRoaXMuX3BhcnRzLnF1ZXJ5ID0gbnVsbDtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHRoaXMucXVlcnkoVVJJLnBhcnNlUXVlcnkodGhpcy5fcGFydHMucXVlcnksIHRoaXMuX3BhcnRzLmVzY2FwZVF1ZXJ5U3BhY2UpKTtcbiAgICAgIH1cblxuICAgICAgdGhpcy5idWlsZCghYnVpbGQpO1xuICAgIH1cblxuICAgIHJldHVybiB0aGlzO1xuICB9O1xuICBwLm5vcm1hbGl6ZUZyYWdtZW50ID0gZnVuY3Rpb24oYnVpbGQpIHtcbiAgICBpZiAoIXRoaXMuX3BhcnRzLmZyYWdtZW50KSB7XG4gICAgICB0aGlzLl9wYXJ0cy5mcmFnbWVudCA9IG51bGw7XG4gICAgICB0aGlzLmJ1aWxkKCFidWlsZCk7XG4gICAgfVxuXG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG4gIHAubm9ybWFsaXplU2VhcmNoID0gcC5ub3JtYWxpemVRdWVyeTtcbiAgcC5ub3JtYWxpemVIYXNoID0gcC5ub3JtYWxpemVGcmFnbWVudDtcblxuICBwLmlzbzg4NTkgPSBmdW5jdGlvbigpIHtcbiAgICAvLyBleHBlY3QgdW5pY29kZSBpbnB1dCwgaXNvODg1OSBvdXRwdXRcbiAgICB2YXIgZSA9IFVSSS5lbmNvZGU7XG4gICAgdmFyIGQgPSBVUkkuZGVjb2RlO1xuXG4gICAgVVJJLmVuY29kZSA9IGVzY2FwZTtcbiAgICBVUkkuZGVjb2RlID0gZGVjb2RlVVJJQ29tcG9uZW50O1xuICAgIHRyeSB7XG4gICAgICB0aGlzLm5vcm1hbGl6ZSgpO1xuICAgIH0gZmluYWxseSB7XG4gICAgICBVUkkuZW5jb2RlID0gZTtcbiAgICAgIFVSSS5kZWNvZGUgPSBkO1xuICAgIH1cbiAgICByZXR1cm4gdGhpcztcbiAgfTtcblxuICBwLnVuaWNvZGUgPSBmdW5jdGlvbigpIHtcbiAgICAvLyBleHBlY3QgaXNvODg1OSBpbnB1dCwgdW5pY29kZSBvdXRwdXRcbiAgICB2YXIgZSA9IFVSSS5lbmNvZGU7XG4gICAgdmFyIGQgPSBVUkkuZGVjb2RlO1xuXG4gICAgVVJJLmVuY29kZSA9IHN0cmljdEVuY29kZVVSSUNvbXBvbmVudDtcbiAgICBVUkkuZGVjb2RlID0gdW5lc2NhcGU7XG4gICAgdHJ5IHtcbiAgICAgIHRoaXMubm9ybWFsaXplKCk7XG4gICAgfSBmaW5hbGx5IHtcbiAgICAgIFVSSS5lbmNvZGUgPSBlO1xuICAgICAgVVJJLmRlY29kZSA9IGQ7XG4gICAgfVxuICAgIHJldHVybiB0aGlzO1xuICB9O1xuXG4gIHAucmVhZGFibGUgPSBmdW5jdGlvbigpIHtcbiAgICB2YXIgdXJpID0gdGhpcy5jbG9uZSgpO1xuICAgIC8vIHJlbW92aW5nIHVzZXJuYW1lLCBwYXNzd29yZCwgYmVjYXVzZSB0aGV5IHNob3VsZG4ndCBiZSBkaXNwbGF5ZWQgYWNjb3JkaW5nIHRvIFJGQyAzOTg2XG4gICAgdXJpLnVzZXJuYW1lKCcnKS5wYXNzd29yZCgnJykubm9ybWFsaXplKCk7XG4gICAgdmFyIHQgPSAnJztcbiAgICBpZiAodXJpLl9wYXJ0cy5wcm90b2NvbCkge1xuICAgICAgdCArPSB1cmkuX3BhcnRzLnByb3RvY29sICsgJzovLyc7XG4gICAgfVxuXG4gICAgaWYgKHVyaS5fcGFydHMuaG9zdG5hbWUpIHtcbiAgICAgIGlmICh1cmkuaXMoJ3B1bnljb2RlJykgJiYgcHVueWNvZGUpIHtcbiAgICAgICAgdCArPSBwdW55Y29kZS50b1VuaWNvZGUodXJpLl9wYXJ0cy5ob3N0bmFtZSk7XG4gICAgICAgIGlmICh1cmkuX3BhcnRzLnBvcnQpIHtcbiAgICAgICAgICB0ICs9ICc6JyArIHVyaS5fcGFydHMucG9ydDtcbiAgICAgICAgfVxuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdCArPSB1cmkuaG9zdCgpO1xuICAgICAgfVxuICAgIH1cblxuICAgIGlmICh1cmkuX3BhcnRzLmhvc3RuYW1lICYmIHVyaS5fcGFydHMucGF0aCAmJiB1cmkuX3BhcnRzLnBhdGguY2hhckF0KDApICE9PSAnLycpIHtcbiAgICAgIHQgKz0gJy8nO1xuICAgIH1cblxuICAgIHQgKz0gdXJpLnBhdGgodHJ1ZSk7XG4gICAgaWYgKHVyaS5fcGFydHMucXVlcnkpIHtcbiAgICAgIHZhciBxID0gJyc7XG4gICAgICBmb3IgKHZhciBpID0gMCwgcXAgPSB1cmkuX3BhcnRzLnF1ZXJ5LnNwbGl0KCcmJyksIGwgPSBxcC5sZW5ndGg7IGkgPCBsOyBpKyspIHtcbiAgICAgICAgdmFyIGt2ID0gKHFwW2ldIHx8ICcnKS5zcGxpdCgnPScpO1xuICAgICAgICBxICs9ICcmJyArIFVSSS5kZWNvZGVRdWVyeShrdlswXSwgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSlcbiAgICAgICAgICAucmVwbGFjZSgvJi9nLCAnJTI2Jyk7XG5cbiAgICAgICAgaWYgKGt2WzFdICE9PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICBxICs9ICc9JyArIFVSSS5kZWNvZGVRdWVyeShrdlsxXSwgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSlcbiAgICAgICAgICAgIC5yZXBsYWNlKC8mL2csICclMjYnKTtcbiAgICAgICAgfVxuICAgICAgfVxuICAgICAgdCArPSAnPycgKyBxLnN1YnN0cmluZygxKTtcbiAgICB9XG5cbiAgICB0ICs9IFVSSS5kZWNvZGVRdWVyeSh1cmkuaGFzaCgpLCB0cnVlKTtcbiAgICByZXR1cm4gdDtcbiAgfTtcblxuICAvLyByZXNvbHZpbmcgcmVsYXRpdmUgYW5kIGFic29sdXRlIFVSTHNcbiAgcC5hYnNvbHV0ZVRvID0gZnVuY3Rpb24oYmFzZSkge1xuICAgIHZhciByZXNvbHZlZCA9IHRoaXMuY2xvbmUoKTtcbiAgICB2YXIgcHJvcGVydGllcyA9IFsncHJvdG9jb2wnLCAndXNlcm5hbWUnLCAncGFzc3dvcmQnLCAnaG9zdG5hbWUnLCAncG9ydCddO1xuICAgIHZhciBiYXNlZGlyLCBpLCBwO1xuXG4gICAgaWYgKHRoaXMuX3BhcnRzLnVybikge1xuICAgICAgdGhyb3cgbmV3IEVycm9yKCdVUk5zIGRvIG5vdCBoYXZlIGFueSBnZW5lcmFsbHkgZGVmaW5lZCBoaWVyYXJjaGljYWwgY29tcG9uZW50cycpO1xuICAgIH1cblxuICAgIGlmICghKGJhc2UgaW5zdGFuY2VvZiBVUkkpKSB7XG4gICAgICBiYXNlID0gbmV3IFVSSShiYXNlKTtcbiAgICB9XG5cbiAgICBpZiAoIXJlc29sdmVkLl9wYXJ0cy5wcm90b2NvbCkge1xuICAgICAgcmVzb2x2ZWQuX3BhcnRzLnByb3RvY29sID0gYmFzZS5fcGFydHMucHJvdG9jb2w7XG4gICAgfVxuXG4gICAgaWYgKHRoaXMuX3BhcnRzLmhvc3RuYW1lKSB7XG4gICAgICByZXR1cm4gcmVzb2x2ZWQ7XG4gICAgfVxuXG4gICAgZm9yIChpID0gMDsgKHAgPSBwcm9wZXJ0aWVzW2ldKTsgaSsrKSB7XG4gICAgICByZXNvbHZlZC5fcGFydHNbcF0gPSBiYXNlLl9wYXJ0c1twXTtcbiAgICB9XG5cbiAgICBpZiAoIXJlc29sdmVkLl9wYXJ0cy5wYXRoKSB7XG4gICAgICByZXNvbHZlZC5fcGFydHMucGF0aCA9IGJhc2UuX3BhcnRzLnBhdGg7XG4gICAgICBpZiAoIXJlc29sdmVkLl9wYXJ0cy5xdWVyeSkge1xuICAgICAgICByZXNvbHZlZC5fcGFydHMucXVlcnkgPSBiYXNlLl9wYXJ0cy5xdWVyeTtcbiAgICAgIH1cbiAgICB9IGVsc2UgaWYgKHJlc29sdmVkLl9wYXJ0cy5wYXRoLnN1YnN0cmluZygtMikgPT09ICcuLicpIHtcbiAgICAgIHJlc29sdmVkLl9wYXJ0cy5wYXRoICs9ICcvJztcbiAgICB9XG5cbiAgICBpZiAocmVzb2x2ZWQucGF0aCgpLmNoYXJBdCgwKSAhPT0gJy8nKSB7XG4gICAgICBiYXNlZGlyID0gYmFzZS5kaXJlY3RvcnkoKTtcbiAgICAgIGJhc2VkaXIgPSBiYXNlZGlyID8gYmFzZWRpciA6IGJhc2UucGF0aCgpLmluZGV4T2YoJy8nKSA9PT0gMCA/ICcvJyA6ICcnO1xuICAgICAgcmVzb2x2ZWQuX3BhcnRzLnBhdGggPSAoYmFzZWRpciA/IChiYXNlZGlyICsgJy8nKSA6ICcnKSArIHJlc29sdmVkLl9wYXJ0cy5wYXRoO1xuICAgICAgcmVzb2x2ZWQubm9ybWFsaXplUGF0aCgpO1xuICAgIH1cblxuICAgIHJlc29sdmVkLmJ1aWxkKCk7XG4gICAgcmV0dXJuIHJlc29sdmVkO1xuICB9O1xuICBwLnJlbGF0aXZlVG8gPSBmdW5jdGlvbihiYXNlKSB7XG4gICAgdmFyIHJlbGF0aXZlID0gdGhpcy5jbG9uZSgpLm5vcm1hbGl6ZSgpO1xuICAgIHZhciByZWxhdGl2ZVBhcnRzLCBiYXNlUGFydHMsIGNvbW1vbiwgcmVsYXRpdmVQYXRoLCBiYXNlUGF0aDtcblxuICAgIGlmIChyZWxhdGl2ZS5fcGFydHMudXJuKSB7XG4gICAgICB0aHJvdyBuZXcgRXJyb3IoJ1VSTnMgZG8gbm90IGhhdmUgYW55IGdlbmVyYWxseSBkZWZpbmVkIGhpZXJhcmNoaWNhbCBjb21wb25lbnRzJyk7XG4gICAgfVxuXG4gICAgYmFzZSA9IG5ldyBVUkkoYmFzZSkubm9ybWFsaXplKCk7XG4gICAgcmVsYXRpdmVQYXJ0cyA9IHJlbGF0aXZlLl9wYXJ0cztcbiAgICBiYXNlUGFydHMgPSBiYXNlLl9wYXJ0cztcbiAgICByZWxhdGl2ZVBhdGggPSByZWxhdGl2ZS5wYXRoKCk7XG4gICAgYmFzZVBhdGggPSBiYXNlLnBhdGgoKTtcblxuICAgIGlmIChyZWxhdGl2ZVBhdGguY2hhckF0KDApICE9PSAnLycpIHtcbiAgICAgIHRocm93IG5ldyBFcnJvcignVVJJIGlzIGFscmVhZHkgcmVsYXRpdmUnKTtcbiAgICB9XG5cbiAgICBpZiAoYmFzZVBhdGguY2hhckF0KDApICE9PSAnLycpIHtcbiAgICAgIHRocm93IG5ldyBFcnJvcignQ2Fubm90IGNhbGN1bGF0ZSBhIFVSSSByZWxhdGl2ZSB0byBhbm90aGVyIHJlbGF0aXZlIFVSSScpO1xuICAgIH1cblxuICAgIGlmIChyZWxhdGl2ZVBhcnRzLnByb3RvY29sID09PSBiYXNlUGFydHMucHJvdG9jb2wpIHtcbiAgICAgIHJlbGF0aXZlUGFydHMucHJvdG9jb2wgPSBudWxsO1xuICAgIH1cblxuICAgIGlmIChyZWxhdGl2ZVBhcnRzLnVzZXJuYW1lICE9PSBiYXNlUGFydHMudXNlcm5hbWUgfHwgcmVsYXRpdmVQYXJ0cy5wYXNzd29yZCAhPT0gYmFzZVBhcnRzLnBhc3N3b3JkKSB7XG4gICAgICByZXR1cm4gcmVsYXRpdmUuYnVpbGQoKTtcbiAgICB9XG5cbiAgICBpZiAocmVsYXRpdmVQYXJ0cy5wcm90b2NvbCAhPT0gbnVsbCB8fCByZWxhdGl2ZVBhcnRzLnVzZXJuYW1lICE9PSBudWxsIHx8IHJlbGF0aXZlUGFydHMucGFzc3dvcmQgIT09IG51bGwpIHtcbiAgICAgIHJldHVybiByZWxhdGl2ZS5idWlsZCgpO1xuICAgIH1cblxuICAgIGlmIChyZWxhdGl2ZVBhcnRzLmhvc3RuYW1lID09PSBiYXNlUGFydHMuaG9zdG5hbWUgJiYgcmVsYXRpdmVQYXJ0cy5wb3J0ID09PSBiYXNlUGFydHMucG9ydCkge1xuICAgICAgcmVsYXRpdmVQYXJ0cy5ob3N0bmFtZSA9IG51bGw7XG4gICAgICByZWxhdGl2ZVBhcnRzLnBvcnQgPSBudWxsO1xuICAgIH0gZWxzZSB7XG4gICAgICByZXR1cm4gcmVsYXRpdmUuYnVpbGQoKTtcbiAgICB9XG5cbiAgICBpZiAocmVsYXRpdmVQYXRoID09PSBiYXNlUGF0aCkge1xuICAgICAgcmVsYXRpdmVQYXJ0cy5wYXRoID0gJyc7XG4gICAgICByZXR1cm4gcmVsYXRpdmUuYnVpbGQoKTtcbiAgICB9XG5cbiAgICAvLyBkZXRlcm1pbmUgY29tbW9uIHN1YiBwYXRoXG4gICAgY29tbW9uID0gVVJJLmNvbW1vblBhdGgocmVsYXRpdmVQYXRoLCBiYXNlUGF0aCk7XG5cbiAgICAvLyBJZiB0aGUgcGF0aHMgaGF2ZSBub3RoaW5nIGluIGNvbW1vbiwgcmV0dXJuIGEgcmVsYXRpdmUgVVJMIHdpdGggdGhlIGFic29sdXRlIHBhdGguXG4gICAgaWYgKCFjb21tb24pIHtcbiAgICAgIHJldHVybiByZWxhdGl2ZS5idWlsZCgpO1xuICAgIH1cblxuICAgIHZhciBwYXJlbnRzID0gYmFzZVBhcnRzLnBhdGhcbiAgICAgIC5zdWJzdHJpbmcoY29tbW9uLmxlbmd0aClcbiAgICAgIC5yZXBsYWNlKC9bXlxcL10qJC8sICcnKVxuICAgICAgLnJlcGxhY2UoLy4qP1xcLy9nLCAnLi4vJyk7XG5cbiAgICByZWxhdGl2ZVBhcnRzLnBhdGggPSAocGFyZW50cyArIHJlbGF0aXZlUGFydHMucGF0aC5zdWJzdHJpbmcoY29tbW9uLmxlbmd0aCkpIHx8ICcuLyc7XG5cbiAgICByZXR1cm4gcmVsYXRpdmUuYnVpbGQoKTtcbiAgfTtcblxuICAvLyBjb21wYXJpbmcgVVJJc1xuICBwLmVxdWFscyA9IGZ1bmN0aW9uKHVyaSkge1xuICAgIHZhciBvbmUgPSB0aGlzLmNsb25lKCk7XG4gICAgdmFyIHR3byA9IG5ldyBVUkkodXJpKTtcbiAgICB2YXIgb25lX21hcCA9IHt9O1xuICAgIHZhciB0d29fbWFwID0ge307XG4gICAgdmFyIGNoZWNrZWQgPSB7fTtcbiAgICB2YXIgb25lX3F1ZXJ5LCB0d29fcXVlcnksIGtleTtcblxuICAgIG9uZS5ub3JtYWxpemUoKTtcbiAgICB0d28ubm9ybWFsaXplKCk7XG5cbiAgICAvLyBleGFjdCBtYXRjaFxuICAgIGlmIChvbmUudG9TdHJpbmcoKSA9PT0gdHdvLnRvU3RyaW5nKCkpIHtcbiAgICAgIHJldHVybiB0cnVlO1xuICAgIH1cblxuICAgIC8vIGV4dHJhY3QgcXVlcnkgc3RyaW5nXG4gICAgb25lX3F1ZXJ5ID0gb25lLnF1ZXJ5KCk7XG4gICAgdHdvX3F1ZXJ5ID0gdHdvLnF1ZXJ5KCk7XG4gICAgb25lLnF1ZXJ5KCcnKTtcbiAgICB0d28ucXVlcnkoJycpO1xuXG4gICAgLy8gZGVmaW5pdGVseSBub3QgZXF1YWwgaWYgbm90IGV2ZW4gbm9uLXF1ZXJ5IHBhcnRzIG1hdGNoXG4gICAgaWYgKG9uZS50b1N0cmluZygpICE9PSB0d28udG9TdHJpbmcoKSkge1xuICAgICAgcmV0dXJuIGZhbHNlO1xuICAgIH1cblxuICAgIC8vIHF1ZXJ5IHBhcmFtZXRlcnMgaGF2ZSB0aGUgc2FtZSBsZW5ndGgsIGV2ZW4gaWYgdGhleSdyZSBwZXJtdXRlZFxuICAgIGlmIChvbmVfcXVlcnkubGVuZ3RoICE9PSB0d29fcXVlcnkubGVuZ3RoKSB7XG4gICAgICByZXR1cm4gZmFsc2U7XG4gICAgfVxuXG4gICAgb25lX21hcCA9IFVSSS5wYXJzZVF1ZXJ5KG9uZV9xdWVyeSwgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSk7XG4gICAgdHdvX21hcCA9IFVSSS5wYXJzZVF1ZXJ5KHR3b19xdWVyeSwgdGhpcy5fcGFydHMuZXNjYXBlUXVlcnlTcGFjZSk7XG5cbiAgICBmb3IgKGtleSBpbiBvbmVfbWFwKSB7XG4gICAgICBpZiAoaGFzT3duLmNhbGwob25lX21hcCwga2V5KSkge1xuICAgICAgICBpZiAoIWlzQXJyYXkob25lX21hcFtrZXldKSkge1xuICAgICAgICAgIGlmIChvbmVfbWFwW2tleV0gIT09IHR3b19tYXBba2V5XSkge1xuICAgICAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgICAgIH1cbiAgICAgICAgfSBlbHNlIGlmICghYXJyYXlzRXF1YWwob25lX21hcFtrZXldLCB0d29fbWFwW2tleV0pKSB7XG4gICAgICAgICAgcmV0dXJuIGZhbHNlO1xuICAgICAgICB9XG5cbiAgICAgICAgY2hlY2tlZFtrZXldID0gdHJ1ZTtcbiAgICAgIH1cbiAgICB9XG5cbiAgICBmb3IgKGtleSBpbiB0d29fbWFwKSB7XG4gICAgICBpZiAoaGFzT3duLmNhbGwodHdvX21hcCwga2V5KSkge1xuICAgICAgICBpZiAoIWNoZWNrZWRba2V5XSkge1xuICAgICAgICAgIC8vIHR3byBjb250YWlucyBhIHBhcmFtZXRlciBub3QgcHJlc2VudCBpbiBvbmVcbiAgICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICAgIH1cbiAgICAgIH1cbiAgICB9XG5cbiAgICByZXR1cm4gdHJ1ZTtcbiAgfTtcblxuICAvLyBzdGF0ZVxuICBwLmR1cGxpY2F0ZVF1ZXJ5UGFyYW1ldGVycyA9IGZ1bmN0aW9uKHYpIHtcbiAgICB0aGlzLl9wYXJ0cy5kdXBsaWNhdGVRdWVyeVBhcmFtZXRlcnMgPSAhIXY7XG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG5cbiAgcC5lc2NhcGVRdWVyeVNwYWNlID0gZnVuY3Rpb24odikge1xuICAgIHRoaXMuX3BhcnRzLmVzY2FwZVF1ZXJ5U3BhY2UgPSAhIXY7XG4gICAgcmV0dXJuIHRoaXM7XG4gIH07XG5cbiAgcmV0dXJuIFVSSTtcbn0pKTtcbiIsIi8qISBodHRwOi8vbXRocy5iZS9wdW55Y29kZSB2MS4yLjMgYnkgQG1hdGhpYXMgKi9cbjsoZnVuY3Rpb24ocm9vdCkge1xuXG5cdC8qKiBEZXRlY3QgZnJlZSB2YXJpYWJsZXMgKi9cblx0dmFyIGZyZWVFeHBvcnRzID0gdHlwZW9mIGV4cG9ydHMgPT0gJ29iamVjdCcgJiYgZXhwb3J0cztcblx0dmFyIGZyZWVNb2R1bGUgPSB0eXBlb2YgbW9kdWxlID09ICdvYmplY3QnICYmIG1vZHVsZSAmJlxuXHRcdG1vZHVsZS5leHBvcnRzID09IGZyZWVFeHBvcnRzICYmIG1vZHVsZTtcblx0dmFyIGZyZWVHbG9iYWwgPSB0eXBlb2YgZ2xvYmFsID09ICdvYmplY3QnICYmIGdsb2JhbDtcblx0aWYgKGZyZWVHbG9iYWwuZ2xvYmFsID09PSBmcmVlR2xvYmFsIHx8IGZyZWVHbG9iYWwud2luZG93ID09PSBmcmVlR2xvYmFsKSB7XG5cdFx0cm9vdCA9IGZyZWVHbG9iYWw7XG5cdH1cblxuXHQvKipcblx0ICogVGhlIGBwdW55Y29kZWAgb2JqZWN0LlxuXHQgKiBAbmFtZSBwdW55Y29kZVxuXHQgKiBAdHlwZSBPYmplY3Rcblx0ICovXG5cdHZhciBwdW55Y29kZSxcblxuXHQvKiogSGlnaGVzdCBwb3NpdGl2ZSBzaWduZWQgMzItYml0IGZsb2F0IHZhbHVlICovXG5cdG1heEludCA9IDIxNDc0ODM2NDcsIC8vIGFrYS4gMHg3RkZGRkZGRiBvciAyXjMxLTFcblxuXHQvKiogQm9vdHN0cmluZyBwYXJhbWV0ZXJzICovXG5cdGJhc2UgPSAzNixcblx0dE1pbiA9IDEsXG5cdHRNYXggPSAyNixcblx0c2tldyA9IDM4LFxuXHRkYW1wID0gNzAwLFxuXHRpbml0aWFsQmlhcyA9IDcyLFxuXHRpbml0aWFsTiA9IDEyOCwgLy8gMHg4MFxuXHRkZWxpbWl0ZXIgPSAnLScsIC8vICdcXHgyRCdcblxuXHQvKiogUmVndWxhciBleHByZXNzaW9ucyAqL1xuXHRyZWdleFB1bnljb2RlID0gL154bi0tLyxcblx0cmVnZXhOb25BU0NJSSA9IC9bXiAtfl0vLCAvLyB1bnByaW50YWJsZSBBU0NJSSBjaGFycyArIG5vbi1BU0NJSSBjaGFyc1xuXHRyZWdleFNlcGFyYXRvcnMgPSAvXFx4MkV8XFx1MzAwMnxcXHVGRjBFfFxcdUZGNjEvZywgLy8gUkZDIDM0OTAgc2VwYXJhdG9yc1xuXG5cdC8qKiBFcnJvciBtZXNzYWdlcyAqL1xuXHRlcnJvcnMgPSB7XG5cdFx0J292ZXJmbG93JzogJ092ZXJmbG93OiBpbnB1dCBuZWVkcyB3aWRlciBpbnRlZ2VycyB0byBwcm9jZXNzJyxcblx0XHQnbm90LWJhc2ljJzogJ0lsbGVnYWwgaW5wdXQgPj0gMHg4MCAobm90IGEgYmFzaWMgY29kZSBwb2ludCknLFxuXHRcdCdpbnZhbGlkLWlucHV0JzogJ0ludmFsaWQgaW5wdXQnXG5cdH0sXG5cblx0LyoqIENvbnZlbmllbmNlIHNob3J0Y3V0cyAqL1xuXHRiYXNlTWludXNUTWluID0gYmFzZSAtIHRNaW4sXG5cdGZsb29yID0gTWF0aC5mbG9vcixcblx0c3RyaW5nRnJvbUNoYXJDb2RlID0gU3RyaW5nLmZyb21DaGFyQ29kZSxcblxuXHQvKiogVGVtcG9yYXJ5IHZhcmlhYmxlICovXG5cdGtleTtcblxuXHQvKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKi9cblxuXHQvKipcblx0ICogQSBnZW5lcmljIGVycm9yIHV0aWxpdHkgZnVuY3Rpb24uXG5cdCAqIEBwcml2YXRlXG5cdCAqIEBwYXJhbSB7U3RyaW5nfSB0eXBlIFRoZSBlcnJvciB0eXBlLlxuXHQgKiBAcmV0dXJucyB7RXJyb3J9IFRocm93cyBhIGBSYW5nZUVycm9yYCB3aXRoIHRoZSBhcHBsaWNhYmxlIGVycm9yIG1lc3NhZ2UuXG5cdCAqL1xuXHRmdW5jdGlvbiBlcnJvcih0eXBlKSB7XG5cdFx0dGhyb3cgUmFuZ2VFcnJvcihlcnJvcnNbdHlwZV0pO1xuXHR9XG5cblx0LyoqXG5cdCAqIEEgZ2VuZXJpYyBgQXJyYXkjbWFwYCB1dGlsaXR5IGZ1bmN0aW9uLlxuXHQgKiBAcHJpdmF0ZVxuXHQgKiBAcGFyYW0ge0FycmF5fSBhcnJheSBUaGUgYXJyYXkgdG8gaXRlcmF0ZSBvdmVyLlxuXHQgKiBAcGFyYW0ge0Z1bmN0aW9ufSBjYWxsYmFjayBUaGUgZnVuY3Rpb24gdGhhdCBnZXRzIGNhbGxlZCBmb3IgZXZlcnkgYXJyYXlcblx0ICogaXRlbS5cblx0ICogQHJldHVybnMge0FycmF5fSBBIG5ldyBhcnJheSBvZiB2YWx1ZXMgcmV0dXJuZWQgYnkgdGhlIGNhbGxiYWNrIGZ1bmN0aW9uLlxuXHQgKi9cblx0ZnVuY3Rpb24gbWFwKGFycmF5LCBmbikge1xuXHRcdHZhciBsZW5ndGggPSBhcnJheS5sZW5ndGg7XG5cdFx0d2hpbGUgKGxlbmd0aC0tKSB7XG5cdFx0XHRhcnJheVtsZW5ndGhdID0gZm4oYXJyYXlbbGVuZ3RoXSk7XG5cdFx0fVxuXHRcdHJldHVybiBhcnJheTtcblx0fVxuXG5cdC8qKlxuXHQgKiBBIHNpbXBsZSBgQXJyYXkjbWFwYC1saWtlIHdyYXBwZXIgdG8gd29yayB3aXRoIGRvbWFpbiBuYW1lIHN0cmluZ3MuXG5cdCAqIEBwcml2YXRlXG5cdCAqIEBwYXJhbSB7U3RyaW5nfSBkb21haW4gVGhlIGRvbWFpbiBuYW1lLlxuXHQgKiBAcGFyYW0ge0Z1bmN0aW9ufSBjYWxsYmFjayBUaGUgZnVuY3Rpb24gdGhhdCBnZXRzIGNhbGxlZCBmb3IgZXZlcnlcblx0ICogY2hhcmFjdGVyLlxuXHQgKiBAcmV0dXJucyB7QXJyYXl9IEEgbmV3IHN0cmluZyBvZiBjaGFyYWN0ZXJzIHJldHVybmVkIGJ5IHRoZSBjYWxsYmFja1xuXHQgKiBmdW5jdGlvbi5cblx0ICovXG5cdGZ1bmN0aW9uIG1hcERvbWFpbihzdHJpbmcsIGZuKSB7XG5cdFx0cmV0dXJuIG1hcChzdHJpbmcuc3BsaXQocmVnZXhTZXBhcmF0b3JzKSwgZm4pLmpvaW4oJy4nKTtcblx0fVxuXG5cdC8qKlxuXHQgKiBDcmVhdGVzIGFuIGFycmF5IGNvbnRhaW5pbmcgdGhlIG51bWVyaWMgY29kZSBwb2ludHMgb2YgZWFjaCBVbmljb2RlXG5cdCAqIGNoYXJhY3RlciBpbiB0aGUgc3RyaW5nLiBXaGlsZSBKYXZhU2NyaXB0IHVzZXMgVUNTLTIgaW50ZXJuYWxseSxcblx0ICogdGhpcyBmdW5jdGlvbiB3aWxsIGNvbnZlcnQgYSBwYWlyIG9mIHN1cnJvZ2F0ZSBoYWx2ZXMgKGVhY2ggb2Ygd2hpY2hcblx0ICogVUNTLTIgZXhwb3NlcyBhcyBzZXBhcmF0ZSBjaGFyYWN0ZXJzKSBpbnRvIGEgc2luZ2xlIGNvZGUgcG9pbnQsXG5cdCAqIG1hdGNoaW5nIFVURi0xNi5cblx0ICogQHNlZSBgcHVueWNvZGUudWNzMi5lbmNvZGVgXG5cdCAqIEBzZWUgPGh0dHA6Ly9tYXRoaWFzYnluZW5zLmJlL25vdGVzL2phdmFzY3JpcHQtZW5jb2Rpbmc+XG5cdCAqIEBtZW1iZXJPZiBwdW55Y29kZS51Y3MyXG5cdCAqIEBuYW1lIGRlY29kZVxuXHQgKiBAcGFyYW0ge1N0cmluZ30gc3RyaW5nIFRoZSBVbmljb2RlIGlucHV0IHN0cmluZyAoVUNTLTIpLlxuXHQgKiBAcmV0dXJucyB7QXJyYXl9IFRoZSBuZXcgYXJyYXkgb2YgY29kZSBwb2ludHMuXG5cdCAqL1xuXHRmdW5jdGlvbiB1Y3MyZGVjb2RlKHN0cmluZykge1xuXHRcdHZhciBvdXRwdXQgPSBbXSxcblx0XHQgICAgY291bnRlciA9IDAsXG5cdFx0ICAgIGxlbmd0aCA9IHN0cmluZy5sZW5ndGgsXG5cdFx0ICAgIHZhbHVlLFxuXHRcdCAgICBleHRyYTtcblx0XHR3aGlsZSAoY291bnRlciA8IGxlbmd0aCkge1xuXHRcdFx0dmFsdWUgPSBzdHJpbmcuY2hhckNvZGVBdChjb3VudGVyKyspO1xuXHRcdFx0aWYgKHZhbHVlID49IDB4RDgwMCAmJiB2YWx1ZSA8PSAweERCRkYgJiYgY291bnRlciA8IGxlbmd0aCkge1xuXHRcdFx0XHQvLyBoaWdoIHN1cnJvZ2F0ZSwgYW5kIHRoZXJlIGlzIGEgbmV4dCBjaGFyYWN0ZXJcblx0XHRcdFx0ZXh0cmEgPSBzdHJpbmcuY2hhckNvZGVBdChjb3VudGVyKyspO1xuXHRcdFx0XHRpZiAoKGV4dHJhICYgMHhGQzAwKSA9PSAweERDMDApIHsgLy8gbG93IHN1cnJvZ2F0ZVxuXHRcdFx0XHRcdG91dHB1dC5wdXNoKCgodmFsdWUgJiAweDNGRikgPDwgMTApICsgKGV4dHJhICYgMHgzRkYpICsgMHgxMDAwMCk7XG5cdFx0XHRcdH0gZWxzZSB7XG5cdFx0XHRcdFx0Ly8gdW5tYXRjaGVkIHN1cnJvZ2F0ZTsgb25seSBhcHBlbmQgdGhpcyBjb2RlIHVuaXQsIGluIGNhc2UgdGhlIG5leHRcblx0XHRcdFx0XHQvLyBjb2RlIHVuaXQgaXMgdGhlIGhpZ2ggc3Vycm9nYXRlIG9mIGEgc3Vycm9nYXRlIHBhaXJcblx0XHRcdFx0XHRvdXRwdXQucHVzaCh2YWx1ZSk7XG5cdFx0XHRcdFx0Y291bnRlci0tO1xuXHRcdFx0XHR9XG5cdFx0XHR9IGVsc2Uge1xuXHRcdFx0XHRvdXRwdXQucHVzaCh2YWx1ZSk7XG5cdFx0XHR9XG5cdFx0fVxuXHRcdHJldHVybiBvdXRwdXQ7XG5cdH1cblxuXHQvKipcblx0ICogQ3JlYXRlcyBhIHN0cmluZyBiYXNlZCBvbiBhbiBhcnJheSBvZiBudW1lcmljIGNvZGUgcG9pbnRzLlxuXHQgKiBAc2VlIGBwdW55Y29kZS51Y3MyLmRlY29kZWBcblx0ICogQG1lbWJlck9mIHB1bnljb2RlLnVjczJcblx0ICogQG5hbWUgZW5jb2RlXG5cdCAqIEBwYXJhbSB7QXJyYXl9IGNvZGVQb2ludHMgVGhlIGFycmF5IG9mIG51bWVyaWMgY29kZSBwb2ludHMuXG5cdCAqIEByZXR1cm5zIHtTdHJpbmd9IFRoZSBuZXcgVW5pY29kZSBzdHJpbmcgKFVDUy0yKS5cblx0ICovXG5cdGZ1bmN0aW9uIHVjczJlbmNvZGUoYXJyYXkpIHtcblx0XHRyZXR1cm4gbWFwKGFycmF5LCBmdW5jdGlvbih2YWx1ZSkge1xuXHRcdFx0dmFyIG91dHB1dCA9ICcnO1xuXHRcdFx0aWYgKHZhbHVlID4gMHhGRkZGKSB7XG5cdFx0XHRcdHZhbHVlIC09IDB4MTAwMDA7XG5cdFx0XHRcdG91dHB1dCArPSBzdHJpbmdGcm9tQ2hhckNvZGUodmFsdWUgPj4+IDEwICYgMHgzRkYgfCAweEQ4MDApO1xuXHRcdFx0XHR2YWx1ZSA9IDB4REMwMCB8IHZhbHVlICYgMHgzRkY7XG5cdFx0XHR9XG5cdFx0XHRvdXRwdXQgKz0gc3RyaW5nRnJvbUNoYXJDb2RlKHZhbHVlKTtcblx0XHRcdHJldHVybiBvdXRwdXQ7XG5cdFx0fSkuam9pbignJyk7XG5cdH1cblxuXHQvKipcblx0ICogQ29udmVydHMgYSBiYXNpYyBjb2RlIHBvaW50IGludG8gYSBkaWdpdC9pbnRlZ2VyLlxuXHQgKiBAc2VlIGBkaWdpdFRvQmFzaWMoKWBcblx0ICogQHByaXZhdGVcblx0ICogQHBhcmFtIHtOdW1iZXJ9IGNvZGVQb2ludCBUaGUgYmFzaWMgbnVtZXJpYyBjb2RlIHBvaW50IHZhbHVlLlxuXHQgKiBAcmV0dXJucyB7TnVtYmVyfSBUaGUgbnVtZXJpYyB2YWx1ZSBvZiBhIGJhc2ljIGNvZGUgcG9pbnQgKGZvciB1c2UgaW5cblx0ICogcmVwcmVzZW50aW5nIGludGVnZXJzKSBpbiB0aGUgcmFuZ2UgYDBgIHRvIGBiYXNlIC0gMWAsIG9yIGBiYXNlYCBpZlxuXHQgKiB0aGUgY29kZSBwb2ludCBkb2VzIG5vdCByZXByZXNlbnQgYSB2YWx1ZS5cblx0ICovXG5cdGZ1bmN0aW9uIGJhc2ljVG9EaWdpdChjb2RlUG9pbnQpIHtcblx0XHRpZiAoY29kZVBvaW50IC0gNDggPCAxMCkge1xuXHRcdFx0cmV0dXJuIGNvZGVQb2ludCAtIDIyO1xuXHRcdH1cblx0XHRpZiAoY29kZVBvaW50IC0gNjUgPCAyNikge1xuXHRcdFx0cmV0dXJuIGNvZGVQb2ludCAtIDY1O1xuXHRcdH1cblx0XHRpZiAoY29kZVBvaW50IC0gOTcgPCAyNikge1xuXHRcdFx0cmV0dXJuIGNvZGVQb2ludCAtIDk3O1xuXHRcdH1cblx0XHRyZXR1cm4gYmFzZTtcblx0fVxuXG5cdC8qKlxuXHQgKiBDb252ZXJ0cyBhIGRpZ2l0L2ludGVnZXIgaW50byBhIGJhc2ljIGNvZGUgcG9pbnQuXG5cdCAqIEBzZWUgYGJhc2ljVG9EaWdpdCgpYFxuXHQgKiBAcHJpdmF0ZVxuXHQgKiBAcGFyYW0ge051bWJlcn0gZGlnaXQgVGhlIG51bWVyaWMgdmFsdWUgb2YgYSBiYXNpYyBjb2RlIHBvaW50LlxuXHQgKiBAcmV0dXJucyB7TnVtYmVyfSBUaGUgYmFzaWMgY29kZSBwb2ludCB3aG9zZSB2YWx1ZSAod2hlbiB1c2VkIGZvclxuXHQgKiByZXByZXNlbnRpbmcgaW50ZWdlcnMpIGlzIGBkaWdpdGAsIHdoaWNoIG5lZWRzIHRvIGJlIGluIHRoZSByYW5nZVxuXHQgKiBgMGAgdG8gYGJhc2UgLSAxYC4gSWYgYGZsYWdgIGlzIG5vbi16ZXJvLCB0aGUgdXBwZXJjYXNlIGZvcm0gaXNcblx0ICogdXNlZDsgZWxzZSwgdGhlIGxvd2VyY2FzZSBmb3JtIGlzIHVzZWQuIFRoZSBiZWhhdmlvciBpcyB1bmRlZmluZWRcblx0ICogaWYgYGZsYWdgIGlzIG5vbi16ZXJvIGFuZCBgZGlnaXRgIGhhcyBubyB1cHBlcmNhc2UgZm9ybS5cblx0ICovXG5cdGZ1bmN0aW9uIGRpZ2l0VG9CYXNpYyhkaWdpdCwgZmxhZykge1xuXHRcdC8vICAwLi4yNSBtYXAgdG8gQVNDSUkgYS4ueiBvciBBLi5aXG5cdFx0Ly8gMjYuLjM1IG1hcCB0byBBU0NJSSAwLi45XG5cdFx0cmV0dXJuIGRpZ2l0ICsgMjIgKyA3NSAqIChkaWdpdCA8IDI2KSAtICgoZmxhZyAhPSAwKSA8PCA1KTtcblx0fVxuXG5cdC8qKlxuXHQgKiBCaWFzIGFkYXB0YXRpb24gZnVuY3Rpb24gYXMgcGVyIHNlY3Rpb24gMy40IG9mIFJGQyAzNDkyLlxuXHQgKiBodHRwOi8vdG9vbHMuaWV0Zi5vcmcvaHRtbC9yZmMzNDkyI3NlY3Rpb24tMy40XG5cdCAqIEBwcml2YXRlXG5cdCAqL1xuXHRmdW5jdGlvbiBhZGFwdChkZWx0YSwgbnVtUG9pbnRzLCBmaXJzdFRpbWUpIHtcblx0XHR2YXIgayA9IDA7XG5cdFx0ZGVsdGEgPSBmaXJzdFRpbWUgPyBmbG9vcihkZWx0YSAvIGRhbXApIDogZGVsdGEgPj4gMTtcblx0XHRkZWx0YSArPSBmbG9vcihkZWx0YSAvIG51bVBvaW50cyk7XG5cdFx0Zm9yICgvKiBubyBpbml0aWFsaXphdGlvbiAqLzsgZGVsdGEgPiBiYXNlTWludXNUTWluICogdE1heCA+PiAxOyBrICs9IGJhc2UpIHtcblx0XHRcdGRlbHRhID0gZmxvb3IoZGVsdGEgLyBiYXNlTWludXNUTWluKTtcblx0XHR9XG5cdFx0cmV0dXJuIGZsb29yKGsgKyAoYmFzZU1pbnVzVE1pbiArIDEpICogZGVsdGEgLyAoZGVsdGEgKyBza2V3KSk7XG5cdH1cblxuXHQvKipcblx0ICogQ29udmVydHMgYSBQdW55Y29kZSBzdHJpbmcgb2YgQVNDSUktb25seSBzeW1ib2xzIHRvIGEgc3RyaW5nIG9mIFVuaWNvZGVcblx0ICogc3ltYm9scy5cblx0ICogQG1lbWJlck9mIHB1bnljb2RlXG5cdCAqIEBwYXJhbSB7U3RyaW5nfSBpbnB1dCBUaGUgUHVueWNvZGUgc3RyaW5nIG9mIEFTQ0lJLW9ubHkgc3ltYm9scy5cblx0ICogQHJldHVybnMge1N0cmluZ30gVGhlIHJlc3VsdGluZyBzdHJpbmcgb2YgVW5pY29kZSBzeW1ib2xzLlxuXHQgKi9cblx0ZnVuY3Rpb24gZGVjb2RlKGlucHV0KSB7XG5cdFx0Ly8gRG9uJ3QgdXNlIFVDUy0yXG5cdFx0dmFyIG91dHB1dCA9IFtdLFxuXHRcdCAgICBpbnB1dExlbmd0aCA9IGlucHV0Lmxlbmd0aCxcblx0XHQgICAgb3V0LFxuXHRcdCAgICBpID0gMCxcblx0XHQgICAgbiA9IGluaXRpYWxOLFxuXHRcdCAgICBiaWFzID0gaW5pdGlhbEJpYXMsXG5cdFx0ICAgIGJhc2ljLFxuXHRcdCAgICBqLFxuXHRcdCAgICBpbmRleCxcblx0XHQgICAgb2xkaSxcblx0XHQgICAgdyxcblx0XHQgICAgayxcblx0XHQgICAgZGlnaXQsXG5cdFx0ICAgIHQsXG5cdFx0ICAgIGxlbmd0aCxcblx0XHQgICAgLyoqIENhY2hlZCBjYWxjdWxhdGlvbiByZXN1bHRzICovXG5cdFx0ICAgIGJhc2VNaW51c1Q7XG5cblx0XHQvLyBIYW5kbGUgdGhlIGJhc2ljIGNvZGUgcG9pbnRzOiBsZXQgYGJhc2ljYCBiZSB0aGUgbnVtYmVyIG9mIGlucHV0IGNvZGVcblx0XHQvLyBwb2ludHMgYmVmb3JlIHRoZSBsYXN0IGRlbGltaXRlciwgb3IgYDBgIGlmIHRoZXJlIGlzIG5vbmUsIHRoZW4gY29weVxuXHRcdC8vIHRoZSBmaXJzdCBiYXNpYyBjb2RlIHBvaW50cyB0byB0aGUgb3V0cHV0LlxuXG5cdFx0YmFzaWMgPSBpbnB1dC5sYXN0SW5kZXhPZihkZWxpbWl0ZXIpO1xuXHRcdGlmIChiYXNpYyA8IDApIHtcblx0XHRcdGJhc2ljID0gMDtcblx0XHR9XG5cblx0XHRmb3IgKGogPSAwOyBqIDwgYmFzaWM7ICsraikge1xuXHRcdFx0Ly8gaWYgaXQncyBub3QgYSBiYXNpYyBjb2RlIHBvaW50XG5cdFx0XHRpZiAoaW5wdXQuY2hhckNvZGVBdChqKSA+PSAweDgwKSB7XG5cdFx0XHRcdGVycm9yKCdub3QtYmFzaWMnKTtcblx0XHRcdH1cblx0XHRcdG91dHB1dC5wdXNoKGlucHV0LmNoYXJDb2RlQXQoaikpO1xuXHRcdH1cblxuXHRcdC8vIE1haW4gZGVjb2RpbmcgbG9vcDogc3RhcnQganVzdCBhZnRlciB0aGUgbGFzdCBkZWxpbWl0ZXIgaWYgYW55IGJhc2ljIGNvZGVcblx0XHQvLyBwb2ludHMgd2VyZSBjb3BpZWQ7IHN0YXJ0IGF0IHRoZSBiZWdpbm5pbmcgb3RoZXJ3aXNlLlxuXG5cdFx0Zm9yIChpbmRleCA9IGJhc2ljID4gMCA/IGJhc2ljICsgMSA6IDA7IGluZGV4IDwgaW5wdXRMZW5ndGg7IC8qIG5vIGZpbmFsIGV4cHJlc3Npb24gKi8pIHtcblxuXHRcdFx0Ly8gYGluZGV4YCBpcyB0aGUgaW5kZXggb2YgdGhlIG5leHQgY2hhcmFjdGVyIHRvIGJlIGNvbnN1bWVkLlxuXHRcdFx0Ly8gRGVjb2RlIGEgZ2VuZXJhbGl6ZWQgdmFyaWFibGUtbGVuZ3RoIGludGVnZXIgaW50byBgZGVsdGFgLFxuXHRcdFx0Ly8gd2hpY2ggZ2V0cyBhZGRlZCB0byBgaWAuIFRoZSBvdmVyZmxvdyBjaGVja2luZyBpcyBlYXNpZXJcblx0XHRcdC8vIGlmIHdlIGluY3JlYXNlIGBpYCBhcyB3ZSBnbywgdGhlbiBzdWJ0cmFjdCBvZmYgaXRzIHN0YXJ0aW5nXG5cdFx0XHQvLyB2YWx1ZSBhdCB0aGUgZW5kIHRvIG9idGFpbiBgZGVsdGFgLlxuXHRcdFx0Zm9yIChvbGRpID0gaSwgdyA9IDEsIGsgPSBiYXNlOyAvKiBubyBjb25kaXRpb24gKi87IGsgKz0gYmFzZSkge1xuXG5cdFx0XHRcdGlmIChpbmRleCA+PSBpbnB1dExlbmd0aCkge1xuXHRcdFx0XHRcdGVycm9yKCdpbnZhbGlkLWlucHV0Jyk7XG5cdFx0XHRcdH1cblxuXHRcdFx0XHRkaWdpdCA9IGJhc2ljVG9EaWdpdChpbnB1dC5jaGFyQ29kZUF0KGluZGV4KyspKTtcblxuXHRcdFx0XHRpZiAoZGlnaXQgPj0gYmFzZSB8fCBkaWdpdCA+IGZsb29yKChtYXhJbnQgLSBpKSAvIHcpKSB7XG5cdFx0XHRcdFx0ZXJyb3IoJ292ZXJmbG93Jyk7XG5cdFx0XHRcdH1cblxuXHRcdFx0XHRpICs9IGRpZ2l0ICogdztcblx0XHRcdFx0dCA9IGsgPD0gYmlhcyA/IHRNaW4gOiAoayA+PSBiaWFzICsgdE1heCA/IHRNYXggOiBrIC0gYmlhcyk7XG5cblx0XHRcdFx0aWYgKGRpZ2l0IDwgdCkge1xuXHRcdFx0XHRcdGJyZWFrO1xuXHRcdFx0XHR9XG5cblx0XHRcdFx0YmFzZU1pbnVzVCA9IGJhc2UgLSB0O1xuXHRcdFx0XHRpZiAodyA+IGZsb29yKG1heEludCAvIGJhc2VNaW51c1QpKSB7XG5cdFx0XHRcdFx0ZXJyb3IoJ292ZXJmbG93Jyk7XG5cdFx0XHRcdH1cblxuXHRcdFx0XHR3ICo9IGJhc2VNaW51c1Q7XG5cblx0XHRcdH1cblxuXHRcdFx0b3V0ID0gb3V0cHV0Lmxlbmd0aCArIDE7XG5cdFx0XHRiaWFzID0gYWRhcHQoaSAtIG9sZGksIG91dCwgb2xkaSA9PSAwKTtcblxuXHRcdFx0Ly8gYGlgIHdhcyBzdXBwb3NlZCB0byB3cmFwIGFyb3VuZCBmcm9tIGBvdXRgIHRvIGAwYCxcblx0XHRcdC8vIGluY3JlbWVudGluZyBgbmAgZWFjaCB0aW1lLCBzbyB3ZSdsbCBmaXggdGhhdCBub3c6XG5cdFx0XHRpZiAoZmxvb3IoaSAvIG91dCkgPiBtYXhJbnQgLSBuKSB7XG5cdFx0XHRcdGVycm9yKCdvdmVyZmxvdycpO1xuXHRcdFx0fVxuXG5cdFx0XHRuICs9IGZsb29yKGkgLyBvdXQpO1xuXHRcdFx0aSAlPSBvdXQ7XG5cblx0XHRcdC8vIEluc2VydCBgbmAgYXQgcG9zaXRpb24gYGlgIG9mIHRoZSBvdXRwdXRcblx0XHRcdG91dHB1dC5zcGxpY2UoaSsrLCAwLCBuKTtcblxuXHRcdH1cblxuXHRcdHJldHVybiB1Y3MyZW5jb2RlKG91dHB1dCk7XG5cdH1cblxuXHQvKipcblx0ICogQ29udmVydHMgYSBzdHJpbmcgb2YgVW5pY29kZSBzeW1ib2xzIHRvIGEgUHVueWNvZGUgc3RyaW5nIG9mIEFTQ0lJLW9ubHlcblx0ICogc3ltYm9scy5cblx0ICogQG1lbWJlck9mIHB1bnljb2RlXG5cdCAqIEBwYXJhbSB7U3RyaW5nfSBpbnB1dCBUaGUgc3RyaW5nIG9mIFVuaWNvZGUgc3ltYm9scy5cblx0ICogQHJldHVybnMge1N0cmluZ30gVGhlIHJlc3VsdGluZyBQdW55Y29kZSBzdHJpbmcgb2YgQVNDSUktb25seSBzeW1ib2xzLlxuXHQgKi9cblx0ZnVuY3Rpb24gZW5jb2RlKGlucHV0KSB7XG5cdFx0dmFyIG4sXG5cdFx0ICAgIGRlbHRhLFxuXHRcdCAgICBoYW5kbGVkQ1BDb3VudCxcblx0XHQgICAgYmFzaWNMZW5ndGgsXG5cdFx0ICAgIGJpYXMsXG5cdFx0ICAgIGosXG5cdFx0ICAgIG0sXG5cdFx0ICAgIHEsXG5cdFx0ICAgIGssXG5cdFx0ICAgIHQsXG5cdFx0ICAgIGN1cnJlbnRWYWx1ZSxcblx0XHQgICAgb3V0cHV0ID0gW10sXG5cdFx0ICAgIC8qKiBgaW5wdXRMZW5ndGhgIHdpbGwgaG9sZCB0aGUgbnVtYmVyIG9mIGNvZGUgcG9pbnRzIGluIGBpbnB1dGAuICovXG5cdFx0ICAgIGlucHV0TGVuZ3RoLFxuXHRcdCAgICAvKiogQ2FjaGVkIGNhbGN1bGF0aW9uIHJlc3VsdHMgKi9cblx0XHQgICAgaGFuZGxlZENQQ291bnRQbHVzT25lLFxuXHRcdCAgICBiYXNlTWludXNULFxuXHRcdCAgICBxTWludXNUO1xuXG5cdFx0Ly8gQ29udmVydCB0aGUgaW5wdXQgaW4gVUNTLTIgdG8gVW5pY29kZVxuXHRcdGlucHV0ID0gdWNzMmRlY29kZShpbnB1dCk7XG5cblx0XHQvLyBDYWNoZSB0aGUgbGVuZ3RoXG5cdFx0aW5wdXRMZW5ndGggPSBpbnB1dC5sZW5ndGg7XG5cblx0XHQvLyBJbml0aWFsaXplIHRoZSBzdGF0ZVxuXHRcdG4gPSBpbml0aWFsTjtcblx0XHRkZWx0YSA9IDA7XG5cdFx0YmlhcyA9IGluaXRpYWxCaWFzO1xuXG5cdFx0Ly8gSGFuZGxlIHRoZSBiYXNpYyBjb2RlIHBvaW50c1xuXHRcdGZvciAoaiA9IDA7IGogPCBpbnB1dExlbmd0aDsgKytqKSB7XG5cdFx0XHRjdXJyZW50VmFsdWUgPSBpbnB1dFtqXTtcblx0XHRcdGlmIChjdXJyZW50VmFsdWUgPCAweDgwKSB7XG5cdFx0XHRcdG91dHB1dC5wdXNoKHN0cmluZ0Zyb21DaGFyQ29kZShjdXJyZW50VmFsdWUpKTtcblx0XHRcdH1cblx0XHR9XG5cblx0XHRoYW5kbGVkQ1BDb3VudCA9IGJhc2ljTGVuZ3RoID0gb3V0cHV0Lmxlbmd0aDtcblxuXHRcdC8vIGBoYW5kbGVkQ1BDb3VudGAgaXMgdGhlIG51bWJlciBvZiBjb2RlIHBvaW50cyB0aGF0IGhhdmUgYmVlbiBoYW5kbGVkO1xuXHRcdC8vIGBiYXNpY0xlbmd0aGAgaXMgdGhlIG51bWJlciBvZiBiYXNpYyBjb2RlIHBvaW50cy5cblxuXHRcdC8vIEZpbmlzaCB0aGUgYmFzaWMgc3RyaW5nIC0gaWYgaXQgaXMgbm90IGVtcHR5IC0gd2l0aCBhIGRlbGltaXRlclxuXHRcdGlmIChiYXNpY0xlbmd0aCkge1xuXHRcdFx0b3V0cHV0LnB1c2goZGVsaW1pdGVyKTtcblx0XHR9XG5cblx0XHQvLyBNYWluIGVuY29kaW5nIGxvb3A6XG5cdFx0d2hpbGUgKGhhbmRsZWRDUENvdW50IDwgaW5wdXRMZW5ndGgpIHtcblxuXHRcdFx0Ly8gQWxsIG5vbi1iYXNpYyBjb2RlIHBvaW50cyA8IG4gaGF2ZSBiZWVuIGhhbmRsZWQgYWxyZWFkeS4gRmluZCB0aGUgbmV4dFxuXHRcdFx0Ly8gbGFyZ2VyIG9uZTpcblx0XHRcdGZvciAobSA9IG1heEludCwgaiA9IDA7IGogPCBpbnB1dExlbmd0aDsgKytqKSB7XG5cdFx0XHRcdGN1cnJlbnRWYWx1ZSA9IGlucHV0W2pdO1xuXHRcdFx0XHRpZiAoY3VycmVudFZhbHVlID49IG4gJiYgY3VycmVudFZhbHVlIDwgbSkge1xuXHRcdFx0XHRcdG0gPSBjdXJyZW50VmFsdWU7XG5cdFx0XHRcdH1cblx0XHRcdH1cblxuXHRcdFx0Ly8gSW5jcmVhc2UgYGRlbHRhYCBlbm91Z2ggdG8gYWR2YW5jZSB0aGUgZGVjb2RlcidzIDxuLGk+IHN0YXRlIHRvIDxtLDA+LFxuXHRcdFx0Ly8gYnV0IGd1YXJkIGFnYWluc3Qgb3ZlcmZsb3dcblx0XHRcdGhhbmRsZWRDUENvdW50UGx1c09uZSA9IGhhbmRsZWRDUENvdW50ICsgMTtcblx0XHRcdGlmIChtIC0gbiA+IGZsb29yKChtYXhJbnQgLSBkZWx0YSkgLyBoYW5kbGVkQ1BDb3VudFBsdXNPbmUpKSB7XG5cdFx0XHRcdGVycm9yKCdvdmVyZmxvdycpO1xuXHRcdFx0fVxuXG5cdFx0XHRkZWx0YSArPSAobSAtIG4pICogaGFuZGxlZENQQ291bnRQbHVzT25lO1xuXHRcdFx0biA9IG07XG5cblx0XHRcdGZvciAoaiA9IDA7IGogPCBpbnB1dExlbmd0aDsgKytqKSB7XG5cdFx0XHRcdGN1cnJlbnRWYWx1ZSA9IGlucHV0W2pdO1xuXG5cdFx0XHRcdGlmIChjdXJyZW50VmFsdWUgPCBuICYmICsrZGVsdGEgPiBtYXhJbnQpIHtcblx0XHRcdFx0XHRlcnJvcignb3ZlcmZsb3cnKTtcblx0XHRcdFx0fVxuXG5cdFx0XHRcdGlmIChjdXJyZW50VmFsdWUgPT0gbikge1xuXHRcdFx0XHRcdC8vIFJlcHJlc2VudCBkZWx0YSBhcyBhIGdlbmVyYWxpemVkIHZhcmlhYmxlLWxlbmd0aCBpbnRlZ2VyXG5cdFx0XHRcdFx0Zm9yIChxID0gZGVsdGEsIGsgPSBiYXNlOyAvKiBubyBjb25kaXRpb24gKi87IGsgKz0gYmFzZSkge1xuXHRcdFx0XHRcdFx0dCA9IGsgPD0gYmlhcyA/IHRNaW4gOiAoayA+PSBiaWFzICsgdE1heCA/IHRNYXggOiBrIC0gYmlhcyk7XG5cdFx0XHRcdFx0XHRpZiAocSA8IHQpIHtcblx0XHRcdFx0XHRcdFx0YnJlYWs7XG5cdFx0XHRcdFx0XHR9XG5cdFx0XHRcdFx0XHRxTWludXNUID0gcSAtIHQ7XG5cdFx0XHRcdFx0XHRiYXNlTWludXNUID0gYmFzZSAtIHQ7XG5cdFx0XHRcdFx0XHRvdXRwdXQucHVzaChcblx0XHRcdFx0XHRcdFx0c3RyaW5nRnJvbUNoYXJDb2RlKGRpZ2l0VG9CYXNpYyh0ICsgcU1pbnVzVCAlIGJhc2VNaW51c1QsIDApKVxuXHRcdFx0XHRcdFx0KTtcblx0XHRcdFx0XHRcdHEgPSBmbG9vcihxTWludXNUIC8gYmFzZU1pbnVzVCk7XG5cdFx0XHRcdFx0fVxuXG5cdFx0XHRcdFx0b3V0cHV0LnB1c2goc3RyaW5nRnJvbUNoYXJDb2RlKGRpZ2l0VG9CYXNpYyhxLCAwKSkpO1xuXHRcdFx0XHRcdGJpYXMgPSBhZGFwdChkZWx0YSwgaGFuZGxlZENQQ291bnRQbHVzT25lLCBoYW5kbGVkQ1BDb3VudCA9PSBiYXNpY0xlbmd0aCk7XG5cdFx0XHRcdFx0ZGVsdGEgPSAwO1xuXHRcdFx0XHRcdCsraGFuZGxlZENQQ291bnQ7XG5cdFx0XHRcdH1cblx0XHRcdH1cblxuXHRcdFx0KytkZWx0YTtcblx0XHRcdCsrbjtcblxuXHRcdH1cblx0XHRyZXR1cm4gb3V0cHV0LmpvaW4oJycpO1xuXHR9XG5cblx0LyoqXG5cdCAqIENvbnZlcnRzIGEgUHVueWNvZGUgc3RyaW5nIHJlcHJlc2VudGluZyBhIGRvbWFpbiBuYW1lIHRvIFVuaWNvZGUuIE9ubHkgdGhlXG5cdCAqIFB1bnljb2RlZCBwYXJ0cyBvZiB0aGUgZG9tYWluIG5hbWUgd2lsbCBiZSBjb252ZXJ0ZWQsIGkuZS4gaXQgZG9lc24ndFxuXHQgKiBtYXR0ZXIgaWYgeW91IGNhbGwgaXQgb24gYSBzdHJpbmcgdGhhdCBoYXMgYWxyZWFkeSBiZWVuIGNvbnZlcnRlZCB0b1xuXHQgKiBVbmljb2RlLlxuXHQgKiBAbWVtYmVyT2YgcHVueWNvZGVcblx0ICogQHBhcmFtIHtTdHJpbmd9IGRvbWFpbiBUaGUgUHVueWNvZGUgZG9tYWluIG5hbWUgdG8gY29udmVydCB0byBVbmljb2RlLlxuXHQgKiBAcmV0dXJucyB7U3RyaW5nfSBUaGUgVW5pY29kZSByZXByZXNlbnRhdGlvbiBvZiB0aGUgZ2l2ZW4gUHVueWNvZGVcblx0ICogc3RyaW5nLlxuXHQgKi9cblx0ZnVuY3Rpb24gdG9Vbmljb2RlKGRvbWFpbikge1xuXHRcdHJldHVybiBtYXBEb21haW4oZG9tYWluLCBmdW5jdGlvbihzdHJpbmcpIHtcblx0XHRcdHJldHVybiByZWdleFB1bnljb2RlLnRlc3Qoc3RyaW5nKVxuXHRcdFx0XHQ/IGRlY29kZShzdHJpbmcuc2xpY2UoNCkudG9Mb3dlckNhc2UoKSlcblx0XHRcdFx0OiBzdHJpbmc7XG5cdFx0fSk7XG5cdH1cblxuXHQvKipcblx0ICogQ29udmVydHMgYSBVbmljb2RlIHN0cmluZyByZXByZXNlbnRpbmcgYSBkb21haW4gbmFtZSB0byBQdW55Y29kZS4gT25seSB0aGVcblx0ICogbm9uLUFTQ0lJIHBhcnRzIG9mIHRoZSBkb21haW4gbmFtZSB3aWxsIGJlIGNvbnZlcnRlZCwgaS5lLiBpdCBkb2Vzbid0XG5cdCAqIG1hdHRlciBpZiB5b3UgY2FsbCBpdCB3aXRoIGEgZG9tYWluIHRoYXQncyBhbHJlYWR5IGluIEFTQ0lJLlxuXHQgKiBAbWVtYmVyT2YgcHVueWNvZGVcblx0ICogQHBhcmFtIHtTdHJpbmd9IGRvbWFpbiBUaGUgZG9tYWluIG5hbWUgdG8gY29udmVydCwgYXMgYSBVbmljb2RlIHN0cmluZy5cblx0ICogQHJldHVybnMge1N0cmluZ30gVGhlIFB1bnljb2RlIHJlcHJlc2VudGF0aW9uIG9mIHRoZSBnaXZlbiBkb21haW4gbmFtZS5cblx0ICovXG5cdGZ1bmN0aW9uIHRvQVNDSUkoZG9tYWluKSB7XG5cdFx0cmV0dXJuIG1hcERvbWFpbihkb21haW4sIGZ1bmN0aW9uKHN0cmluZykge1xuXHRcdFx0cmV0dXJuIHJlZ2V4Tm9uQVNDSUkudGVzdChzdHJpbmcpXG5cdFx0XHRcdD8gJ3huLS0nICsgZW5jb2RlKHN0cmluZylcblx0XHRcdFx0OiBzdHJpbmc7XG5cdFx0fSk7XG5cdH1cblxuXHQvKi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tKi9cblxuXHQvKiogRGVmaW5lIHRoZSBwdWJsaWMgQVBJICovXG5cdHB1bnljb2RlID0ge1xuXHRcdC8qKlxuXHRcdCAqIEEgc3RyaW5nIHJlcHJlc2VudGluZyB0aGUgY3VycmVudCBQdW55Y29kZS5qcyB2ZXJzaW9uIG51bWJlci5cblx0XHQgKiBAbWVtYmVyT2YgcHVueWNvZGVcblx0XHQgKiBAdHlwZSBTdHJpbmdcblx0XHQgKi9cblx0XHQndmVyc2lvbic6ICcxLjIuMycsXG5cdFx0LyoqXG5cdFx0ICogQW4gb2JqZWN0IG9mIG1ldGhvZHMgdG8gY29udmVydCBmcm9tIEphdmFTY3JpcHQncyBpbnRlcm5hbCBjaGFyYWN0ZXJcblx0XHQgKiByZXByZXNlbnRhdGlvbiAoVUNTLTIpIHRvIFVuaWNvZGUgY29kZSBwb2ludHMsIGFuZCBiYWNrLlxuXHRcdCAqIEBzZWUgPGh0dHA6Ly9tYXRoaWFzYnluZW5zLmJlL25vdGVzL2phdmFzY3JpcHQtZW5jb2Rpbmc+XG5cdFx0ICogQG1lbWJlck9mIHB1bnljb2RlXG5cdFx0ICogQHR5cGUgT2JqZWN0XG5cdFx0ICovXG5cdFx0J3VjczInOiB7XG5cdFx0XHQnZGVjb2RlJzogdWNzMmRlY29kZSxcblx0XHRcdCdlbmNvZGUnOiB1Y3MyZW5jb2RlXG5cdFx0fSxcblx0XHQnZGVjb2RlJzogZGVjb2RlLFxuXHRcdCdlbmNvZGUnOiBlbmNvZGUsXG5cdFx0J3RvQVNDSUknOiB0b0FTQ0lJLFxuXHRcdCd0b1VuaWNvZGUnOiB0b1VuaWNvZGVcblx0fTtcblxuXHQvKiogRXhwb3NlIGBwdW55Y29kZWAgKi9cblx0Ly8gU29tZSBBTUQgYnVpbGQgb3B0aW1pemVycywgbGlrZSByLmpzLCBjaGVjayBmb3Igc3BlY2lmaWMgY29uZGl0aW9uIHBhdHRlcm5zXG5cdC8vIGxpa2UgdGhlIGZvbGxvd2luZzpcblx0aWYgKFxuXHRcdHR5cGVvZiBkZWZpbmUgPT0gJ2Z1bmN0aW9uJyAmJlxuXHRcdHR5cGVvZiBkZWZpbmUuYW1kID09ICdvYmplY3QnICYmXG5cdFx0ZGVmaW5lLmFtZFxuXHQpIHtcblx0XHRkZWZpbmUoZnVuY3Rpb24oKSB7XG5cdFx0XHRyZXR1cm4gcHVueWNvZGU7XG5cdFx0fSk7XG5cdH1cdGVsc2UgaWYgKGZyZWVFeHBvcnRzICYmICFmcmVlRXhwb3J0cy5ub2RlVHlwZSkge1xuXHRcdGlmIChmcmVlTW9kdWxlKSB7IC8vIGluIE5vZGUuanMgb3IgUmluZ29KUyB2MC44LjArXG5cdFx0XHRmcmVlTW9kdWxlLmV4cG9ydHMgPSBwdW55Y29kZTtcblx0XHR9IGVsc2UgeyAvLyBpbiBOYXJ3aGFsIG9yIFJpbmdvSlMgdjAuNy4wLVxuXHRcdFx0Zm9yIChrZXkgaW4gcHVueWNvZGUpIHtcblx0XHRcdFx0cHVueWNvZGUuaGFzT3duUHJvcGVydHkoa2V5KSAmJiAoZnJlZUV4cG9ydHNba2V5XSA9IHB1bnljb2RlW2tleV0pO1xuXHRcdFx0fVxuXHRcdH1cblx0fSBlbHNlIHsgLy8gaW4gUmhpbm8gb3IgYSB3ZWIgYnJvd3NlclxuXHRcdHJvb3QucHVueWNvZGUgPSBwdW55Y29kZTtcblx0fVxuXG59KHRoaXMpKTtcbiIsIid1c2Ugc3RyaWN0JztcblxuT2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsICdfX2VzTW9kdWxlJywge1xuICB2YWx1ZTogdHJ1ZVxufSk7XG5cbmZ1bmN0aW9uIF9pbnRlcm9wUmVxdWlyZURlZmF1bHQob2JqKSB7IHJldHVybiBvYmogJiYgb2JqLl9fZXNNb2R1bGUgPyBvYmogOiB7ICdkZWZhdWx0Jzogb2JqIH07IH1cblxudmFyIF9oZWxwZXJzRXZlbnQgPSByZXF1aXJlKCcuL2hlbHBlcnMvZXZlbnQnKTtcblxudmFyIF9oZWxwZXJzRXZlbnQyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfaGVscGVyc0V2ZW50KTtcblxudmFyIF9oZWxwZXJzTWVzc2FnZUV2ZW50ID0gcmVxdWlyZSgnLi9oZWxwZXJzL21lc3NhZ2UtZXZlbnQnKTtcblxudmFyIF9oZWxwZXJzTWVzc2FnZUV2ZW50MiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2hlbHBlcnNNZXNzYWdlRXZlbnQpO1xuXG52YXIgX2hlbHBlcnNDbG9zZUV2ZW50ID0gcmVxdWlyZSgnLi9oZWxwZXJzL2Nsb3NlLWV2ZW50Jyk7XG5cbnZhciBfaGVscGVyc0Nsb3NlRXZlbnQyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfaGVscGVyc0Nsb3NlRXZlbnQpO1xuXG4vKlxuKiBDcmVhdGVzIGFuIEV2ZW50IG9iamVjdCBhbmQgZXh0ZW5kcyBpdCB0byBhbGxvdyBmdWxsIG1vZGlmaWNhdGlvbiBvZlxuKiBpdHMgcHJvcGVydGllcy5cbipcbiogQHBhcmFtIHtvYmplY3R9IGNvbmZpZyAtIHdpdGhpbiBjb25maWcgeW91IHdpbGwgbmVlZCB0byBwYXNzIHR5cGUgYW5kIG9wdGlvbmFsbHkgdGFyZ2V0XG4qL1xuZnVuY3Rpb24gY3JlYXRlRXZlbnQoY29uZmlnKSB7XG4gIHZhciB0eXBlID0gY29uZmlnLnR5cGU7XG4gIHZhciB0YXJnZXQgPSBjb25maWcudGFyZ2V0O1xuXG4gIHZhciBldmVudE9iamVjdCA9IG5ldyBfaGVscGVyc0V2ZW50MlsnZGVmYXVsdCddKHR5cGUpO1xuXG4gIGlmICh0YXJnZXQpIHtcbiAgICBldmVudE9iamVjdC50YXJnZXQgPSB0YXJnZXQ7XG4gICAgZXZlbnRPYmplY3Quc3JjRWxlbWVudCA9IHRhcmdldDtcbiAgICBldmVudE9iamVjdC5jdXJyZW50VGFyZ2V0ID0gdGFyZ2V0O1xuICB9XG5cbiAgcmV0dXJuIGV2ZW50T2JqZWN0O1xufVxuXG4vKlxuKiBDcmVhdGVzIGEgTWVzc2FnZUV2ZW50IG9iamVjdCBhbmQgZXh0ZW5kcyBpdCB0byBhbGxvdyBmdWxsIG1vZGlmaWNhdGlvbiBvZlxuKiBpdHMgcHJvcGVydGllcy5cbipcbiogQHBhcmFtIHtvYmplY3R9IGNvbmZpZyAtIHdpdGhpbiBjb25maWcgeW91IHdpbGwgbmVlZCB0byBwYXNzIHR5cGUsIG9yaWdpbiwgZGF0YSBhbmQgb3B0aW9uYWxseSB0YXJnZXRcbiovXG5mdW5jdGlvbiBjcmVhdGVNZXNzYWdlRXZlbnQoY29uZmlnKSB7XG4gIHZhciB0eXBlID0gY29uZmlnLnR5cGU7XG4gIHZhciBvcmlnaW4gPSBjb25maWcub3JpZ2luO1xuICB2YXIgZGF0YSA9IGNvbmZpZy5kYXRhO1xuICB2YXIgdGFyZ2V0ID0gY29uZmlnLnRhcmdldDtcblxuICB2YXIgbWVzc2FnZUV2ZW50ID0gbmV3IF9oZWxwZXJzTWVzc2FnZUV2ZW50MlsnZGVmYXVsdCddKHR5cGUsIHtcbiAgICBkYXRhOiBkYXRhLFxuICAgIG9yaWdpbjogb3JpZ2luXG4gIH0pO1xuXG4gIGlmICh0YXJnZXQpIHtcbiAgICBtZXNzYWdlRXZlbnQudGFyZ2V0ID0gdGFyZ2V0O1xuICAgIG1lc3NhZ2VFdmVudC5zcmNFbGVtZW50ID0gdGFyZ2V0O1xuICAgIG1lc3NhZ2VFdmVudC5jdXJyZW50VGFyZ2V0ID0gdGFyZ2V0O1xuICB9XG5cbiAgcmV0dXJuIG1lc3NhZ2VFdmVudDtcbn1cblxuLypcbiogQ3JlYXRlcyBhIENsb3NlRXZlbnQgb2JqZWN0IGFuZCBleHRlbmRzIGl0IHRvIGFsbG93IGZ1bGwgbW9kaWZpY2F0aW9uIG9mXG4qIGl0cyBwcm9wZXJ0aWVzLlxuKlxuKiBAcGFyYW0ge29iamVjdH0gY29uZmlnIC0gd2l0aGluIGNvbmZpZyB5b3Ugd2lsbCBuZWVkIHRvIHBhc3MgdHlwZSBhbmQgb3B0aW9uYWxseSB0YXJnZXQsIGNvZGUsIGFuZCByZWFzb25cbiovXG5mdW5jdGlvbiBjcmVhdGVDbG9zZUV2ZW50KGNvbmZpZykge1xuICB2YXIgY29kZSA9IGNvbmZpZy5jb2RlO1xuICB2YXIgcmVhc29uID0gY29uZmlnLnJlYXNvbjtcbiAgdmFyIHR5cGUgPSBjb25maWcudHlwZTtcbiAgdmFyIHRhcmdldCA9IGNvbmZpZy50YXJnZXQ7XG4gIHZhciB3YXNDbGVhbiA9IGNvbmZpZy53YXNDbGVhbjtcblxuICBpZiAoIXdhc0NsZWFuKSB7XG4gICAgd2FzQ2xlYW4gPSBjb2RlID09PSAxMDAwO1xuICB9XG5cbiAgdmFyIGNsb3NlRXZlbnQgPSBuZXcgX2hlbHBlcnNDbG9zZUV2ZW50MlsnZGVmYXVsdCddKHR5cGUsIHtcbiAgICBjb2RlOiBjb2RlLFxuICAgIHJlYXNvbjogcmVhc29uLFxuICAgIHdhc0NsZWFuOiB3YXNDbGVhblxuICB9KTtcblxuICBpZiAodGFyZ2V0KSB7XG4gICAgY2xvc2VFdmVudC50YXJnZXQgPSB0YXJnZXQ7XG4gICAgY2xvc2VFdmVudC5zcmNFbGVtZW50ID0gdGFyZ2V0O1xuICAgIGNsb3NlRXZlbnQuY3VycmVudFRhcmdldCA9IHRhcmdldDtcbiAgfVxuXG4gIHJldHVybiBjbG9zZUV2ZW50O1xufVxuXG5leHBvcnRzLmNyZWF0ZUV2ZW50ID0gY3JlYXRlRXZlbnQ7XG5leHBvcnRzLmNyZWF0ZU1lc3NhZ2VFdmVudCA9IGNyZWF0ZU1lc3NhZ2VFdmVudDtcbmV4cG9ydHMuY3JlYXRlQ2xvc2VFdmVudCA9IGNyZWF0ZUNsb3NlRXZlbnQ7IiwiJ3VzZSBzdHJpY3QnO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcblxudmFyIF9jcmVhdGVDbGFzcyA9IChmdW5jdGlvbiAoKSB7IGZ1bmN0aW9uIGRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBwcm9wcykgeyBmb3IgKHZhciBpID0gMDsgaSA8IHByb3BzLmxlbmd0aDsgaSsrKSB7IHZhciBkZXNjcmlwdG9yID0gcHJvcHNbaV07IGRlc2NyaXB0b3IuZW51bWVyYWJsZSA9IGRlc2NyaXB0b3IuZW51bWVyYWJsZSB8fCBmYWxzZTsgZGVzY3JpcHRvci5jb25maWd1cmFibGUgPSB0cnVlOyBpZiAoJ3ZhbHVlJyBpbiBkZXNjcmlwdG9yKSBkZXNjcmlwdG9yLndyaXRhYmxlID0gdHJ1ZTsgT2JqZWN0LmRlZmluZVByb3BlcnR5KHRhcmdldCwgZGVzY3JpcHRvci5rZXksIGRlc2NyaXB0b3IpOyB9IH0gcmV0dXJuIGZ1bmN0aW9uIChDb25zdHJ1Y3RvciwgcHJvdG9Qcm9wcywgc3RhdGljUHJvcHMpIHsgaWYgKHByb3RvUHJvcHMpIGRlZmluZVByb3BlcnRpZXMoQ29uc3RydWN0b3IucHJvdG90eXBlLCBwcm90b1Byb3BzKTsgaWYgKHN0YXRpY1Byb3BzKSBkZWZpbmVQcm9wZXJ0aWVzKENvbnN0cnVjdG9yLCBzdGF0aWNQcm9wcyk7IHJldHVybiBDb25zdHJ1Y3RvcjsgfTsgfSkoKTtcblxuZnVuY3Rpb24gX2NsYXNzQ2FsbENoZWNrKGluc3RhbmNlLCBDb25zdHJ1Y3RvcikgeyBpZiAoIShpbnN0YW5jZSBpbnN0YW5jZW9mIENvbnN0cnVjdG9yKSkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdDYW5ub3QgY2FsbCBhIGNsYXNzIGFzIGEgZnVuY3Rpb24nKTsgfSB9XG5cbnZhciBfaGVscGVyc0FycmF5SGVscGVycyA9IHJlcXVpcmUoJy4vaGVscGVycy9hcnJheS1oZWxwZXJzJyk7XG5cbi8qXG4qIEV2ZW50VGFyZ2V0IGlzIGFuIGludGVyZmFjZSBpbXBsZW1lbnRlZCBieSBvYmplY3RzIHRoYXQgY2FuXG4qIHJlY2VpdmUgZXZlbnRzIGFuZCBtYXkgaGF2ZSBsaXN0ZW5lcnMgZm9yIHRoZW0uXG4qXG4qIGh0dHBzOi8vZGV2ZWxvcGVyLm1vemlsbGEub3JnL2VuLVVTL2RvY3MvV2ViL0FQSS9FdmVudFRhcmdldFxuKi9cblxudmFyIEV2ZW50VGFyZ2V0ID0gKGZ1bmN0aW9uICgpIHtcbiAgZnVuY3Rpb24gRXZlbnRUYXJnZXQoKSB7XG4gICAgX2NsYXNzQ2FsbENoZWNrKHRoaXMsIEV2ZW50VGFyZ2V0KTtcblxuICAgIHRoaXMubGlzdGVuZXJzID0ge307XG4gIH1cblxuICAvKlxuICAqIFRpZXMgYSBsaXN0ZW5lciBmdW5jdGlvbiB0byBhIGV2ZW50IHR5cGUgd2hpY2ggY2FuIGxhdGVyIGJlIGludm9rZWQgdmlhIHRoZVxuICAqIGRpc3BhdGNoRXZlbnQgbWV0aG9kLlxuICAqXG4gICogQHBhcmFtIHtzdHJpbmd9IHR5cGUgLSB0aGUgdHlwZSBvZiBldmVudCAoaWU6ICdvcGVuJywgJ21lc3NhZ2UnLCBldGMuKVxuICAqIEBwYXJhbSB7ZnVuY3Rpb259IGxpc3RlbmVyIC0gdGhlIGNhbGxiYWNrIGZ1bmN0aW9uIHRvIGludm9rZSB3aGVuZXZlciBhIGV2ZW50IGlzIGRpc3BhdGNoZWQgbWF0Y2hpbmcgdGhlIGdpdmVuIHR5cGVcbiAgKiBAcGFyYW0ge2Jvb2xlYW59IHVzZUNhcHR1cmUgLSBOL0EgVE9ETzogaW1wbGVtZW50IHVzZUNhcHR1cmUgZnVuY3Rpb25hbGl0eVxuICAqL1xuXG4gIF9jcmVhdGVDbGFzcyhFdmVudFRhcmdldCwgW3tcbiAgICBrZXk6ICdhZGRFdmVudExpc3RlbmVyJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gYWRkRXZlbnRMaXN0ZW5lcih0eXBlLCBsaXN0ZW5lciAvKiAsIHVzZUNhcHR1cmUgKi8pIHtcbiAgICAgIGlmICh0eXBlb2YgbGlzdGVuZXIgPT09ICdmdW5jdGlvbicpIHtcbiAgICAgICAgaWYgKCFBcnJheS5pc0FycmF5KHRoaXMubGlzdGVuZXJzW3R5cGVdKSkge1xuICAgICAgICAgIHRoaXMubGlzdGVuZXJzW3R5cGVdID0gW107XG4gICAgICAgIH1cblxuICAgICAgICAvLyBPbmx5IGFkZCB0aGUgc2FtZSBmdW5jdGlvbiBvbmNlXG4gICAgICAgIGlmICgoMCwgX2hlbHBlcnNBcnJheUhlbHBlcnMuZmlsdGVyKSh0aGlzLmxpc3RlbmVyc1t0eXBlXSwgZnVuY3Rpb24gKGl0ZW0pIHtcbiAgICAgICAgICByZXR1cm4gaXRlbSA9PT0gbGlzdGVuZXI7XG4gICAgICAgIH0pLmxlbmd0aCA9PT0gMCkge1xuICAgICAgICAgIHRoaXMubGlzdGVuZXJzW3R5cGVdLnB1c2gobGlzdGVuZXIpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfVxuXG4gICAgLypcbiAgICAqIFJlbW92ZXMgdGhlIGxpc3RlbmVyIHNvIGl0IHdpbGwgbm8gbG9uZ2VyIGJlIGludm9rZWQgdmlhIHRoZSBkaXNwYXRjaEV2ZW50IG1ldGhvZC5cbiAgICAqXG4gICAgKiBAcGFyYW0ge3N0cmluZ30gdHlwZSAtIHRoZSB0eXBlIG9mIGV2ZW50IChpZTogJ29wZW4nLCAnbWVzc2FnZScsIGV0Yy4pXG4gICAgKiBAcGFyYW0ge2Z1bmN0aW9ufSBsaXN0ZW5lciAtIHRoZSBjYWxsYmFjayBmdW5jdGlvbiB0byBpbnZva2Ugd2hlbmV2ZXIgYSBldmVudCBpcyBkaXNwYXRjaGVkIG1hdGNoaW5nIHRoZSBnaXZlbiB0eXBlXG4gICAgKiBAcGFyYW0ge2Jvb2xlYW59IHVzZUNhcHR1cmUgLSBOL0EgVE9ETzogaW1wbGVtZW50IHVzZUNhcHR1cmUgZnVuY3Rpb25hbGl0eVxuICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdyZW1vdmVFdmVudExpc3RlbmVyJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gcmVtb3ZlRXZlbnRMaXN0ZW5lcih0eXBlLCByZW1vdmluZ0xpc3RlbmVyIC8qICwgdXNlQ2FwdHVyZSAqLykge1xuICAgICAgdmFyIGFycmF5T2ZMaXN0ZW5lcnMgPSB0aGlzLmxpc3RlbmVyc1t0eXBlXTtcbiAgICAgIHRoaXMubGlzdGVuZXJzW3R5cGVdID0gKDAsIF9oZWxwZXJzQXJyYXlIZWxwZXJzLnJlamVjdCkoYXJyYXlPZkxpc3RlbmVycywgZnVuY3Rpb24gKGxpc3RlbmVyKSB7XG4gICAgICAgIHJldHVybiBsaXN0ZW5lciA9PT0gcmVtb3ZpbmdMaXN0ZW5lcjtcbiAgICAgIH0pO1xuICAgIH1cblxuICAgIC8qXG4gICAgKiBJbnZva2VzIGFsbCBsaXN0ZW5lciBmdW5jdGlvbnMgdGhhdCBhcmUgbGlzdGVuaW5nIHRvIHRoZSBnaXZlbiBldmVudC50eXBlIHByb3BlcnR5LiBFYWNoXG4gICAgKiBsaXN0ZW5lciB3aWxsIGJlIHBhc3NlZCB0aGUgZXZlbnQgYXMgdGhlIGZpcnN0IGFyZ3VtZW50LlxuICAgICpcbiAgICAqIEBwYXJhbSB7b2JqZWN0fSBldmVudCAtIGV2ZW50IG9iamVjdCB3aGljaCB3aWxsIGJlIHBhc3NlZCB0byBhbGwgbGlzdGVuZXJzIG9mIHRoZSBldmVudC50eXBlIHByb3BlcnR5XG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ2Rpc3BhdGNoRXZlbnQnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBkaXNwYXRjaEV2ZW50KGV2ZW50KSB7XG4gICAgICB2YXIgX3RoaXMgPSB0aGlzO1xuXG4gICAgICBmb3IgKHZhciBfbGVuID0gYXJndW1lbnRzLmxlbmd0aCwgY3VzdG9tQXJndW1lbnRzID0gQXJyYXkoX2xlbiA+IDEgPyBfbGVuIC0gMSA6IDApLCBfa2V5ID0gMTsgX2tleSA8IF9sZW47IF9rZXkrKykge1xuICAgICAgICBjdXN0b21Bcmd1bWVudHNbX2tleSAtIDFdID0gYXJndW1lbnRzW19rZXldO1xuICAgICAgfVxuXG4gICAgICB2YXIgZXZlbnROYW1lID0gZXZlbnQudHlwZTtcbiAgICAgIHZhciBsaXN0ZW5lcnMgPSB0aGlzLmxpc3RlbmVyc1tldmVudE5hbWVdO1xuXG4gICAgICBpZiAoIUFycmF5LmlzQXJyYXkobGlzdGVuZXJzKSkge1xuICAgICAgICByZXR1cm4gZmFsc2U7XG4gICAgICB9XG5cbiAgICAgIGxpc3RlbmVycy5mb3JFYWNoKGZ1bmN0aW9uIChsaXN0ZW5lcikge1xuICAgICAgICBpZiAoY3VzdG9tQXJndW1lbnRzLmxlbmd0aCA+IDApIHtcbiAgICAgICAgICBsaXN0ZW5lci5hcHBseShfdGhpcywgY3VzdG9tQXJndW1lbnRzKTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICBsaXN0ZW5lci5jYWxsKF90aGlzLCBldmVudCk7XG4gICAgICAgIH1cbiAgICAgIH0pO1xuICAgIH1cbiAgfV0pO1xuXG4gIHJldHVybiBFdmVudFRhcmdldDtcbn0pKCk7XG5cbmV4cG9ydHNbJ2RlZmF1bHQnXSA9IEV2ZW50VGFyZ2V0O1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzWydkZWZhdWx0J107IiwiXCJ1c2Ugc3RyaWN0XCI7XG5cbk9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBcIl9fZXNNb2R1bGVcIiwge1xuICB2YWx1ZTogdHJ1ZVxufSk7XG5leHBvcnRzLnJlamVjdCA9IHJlamVjdDtcbmV4cG9ydHMuZmlsdGVyID0gZmlsdGVyO1xuXG5mdW5jdGlvbiByZWplY3QoYXJyYXksIGNhbGxiYWNrKSB7XG4gIHZhciByZXN1bHRzID0gW107XG4gIGFycmF5LmZvckVhY2goZnVuY3Rpb24gKGl0ZW1JbkFycmF5KSB7XG4gICAgaWYgKCFjYWxsYmFjayhpdGVtSW5BcnJheSkpIHtcbiAgICAgIHJlc3VsdHMucHVzaChpdGVtSW5BcnJheSk7XG4gICAgfVxuICB9KTtcblxuICByZXR1cm4gcmVzdWx0cztcbn1cblxuZnVuY3Rpb24gZmlsdGVyKGFycmF5LCBjYWxsYmFjaykge1xuICB2YXIgcmVzdWx0cyA9IFtdO1xuICBhcnJheS5mb3JFYWNoKGZ1bmN0aW9uIChpdGVtSW5BcnJheSkge1xuICAgIGlmIChjYWxsYmFjayhpdGVtSW5BcnJheSkpIHtcbiAgICAgIHJlc3VsdHMucHVzaChpdGVtSW5BcnJheSk7XG4gICAgfVxuICB9KTtcblxuICByZXR1cm4gcmVzdWx0cztcbn0iLCIvKlxuKiBodHRwczovL2RldmVsb3Blci5tb3ppbGxhLm9yZy9lbi1VUy9kb2NzL1dlYi9BUEkvQ2xvc2VFdmVudFxuKi9cblwidXNlIHN0cmljdFwiO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgXCJfX2VzTW9kdWxlXCIsIHtcbiAgdmFsdWU6IHRydWVcbn0pO1xudmFyIGNvZGVzID0ge1xuICBDTE9TRV9OT1JNQUw6IDEwMDAsXG4gIENMT1NFX0dPSU5HX0FXQVk6IDEwMDEsXG4gIENMT1NFX1BST1RPQ09MX0VSUk9SOiAxMDAyLFxuICBDTE9TRV9VTlNVUFBPUlRFRDogMTAwMyxcbiAgQ0xPU0VfTk9fU1RBVFVTOiAxMDA1LFxuICBDTE9TRV9BQk5PUk1BTDogMTAwNixcbiAgQ0xPU0VfVE9PX0xBUkdFOiAxMDA5XG59O1xuXG5leHBvcnRzW1wiZGVmYXVsdFwiXSA9IGNvZGVzO1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzW1wiZGVmYXVsdFwiXTsiLCIndXNlIHN0cmljdCc7XG5cbk9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHtcbiAgdmFsdWU6IHRydWVcbn0pO1xuXG52YXIgX2dldCA9IGZ1bmN0aW9uIGdldChfeDIsIF94MywgX3g0KSB7IHZhciBfYWdhaW4gPSB0cnVlOyBfZnVuY3Rpb246IHdoaWxlIChfYWdhaW4pIHsgdmFyIG9iamVjdCA9IF94MiwgcHJvcGVydHkgPSBfeDMsIHJlY2VpdmVyID0gX3g0OyBfYWdhaW4gPSBmYWxzZTsgaWYgKG9iamVjdCA9PT0gbnVsbCkgb2JqZWN0ID0gRnVuY3Rpb24ucHJvdG90eXBlOyB2YXIgZGVzYyA9IE9iamVjdC5nZXRPd25Qcm9wZXJ0eURlc2NyaXB0b3Iob2JqZWN0LCBwcm9wZXJ0eSk7IGlmIChkZXNjID09PSB1bmRlZmluZWQpIHsgdmFyIHBhcmVudCA9IE9iamVjdC5nZXRQcm90b3R5cGVPZihvYmplY3QpOyBpZiAocGFyZW50ID09PSBudWxsKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gZWxzZSB7IF94MiA9IHBhcmVudDsgX3gzID0gcHJvcGVydHk7IF94NCA9IHJlY2VpdmVyOyBfYWdhaW4gPSB0cnVlOyBkZXNjID0gcGFyZW50ID0gdW5kZWZpbmVkOyBjb250aW51ZSBfZnVuY3Rpb247IH0gfSBlbHNlIGlmICgndmFsdWUnIGluIGRlc2MpIHsgcmV0dXJuIGRlc2MudmFsdWU7IH0gZWxzZSB7IHZhciBnZXR0ZXIgPSBkZXNjLmdldDsgaWYgKGdldHRlciA9PT0gdW5kZWZpbmVkKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gcmV0dXJuIGdldHRlci5jYWxsKHJlY2VpdmVyKTsgfSB9IH07XG5cbmZ1bmN0aW9uIF9pbnRlcm9wUmVxdWlyZURlZmF1bHQob2JqKSB7IHJldHVybiBvYmogJiYgb2JqLl9fZXNNb2R1bGUgPyBvYmogOiB7ICdkZWZhdWx0Jzogb2JqIH07IH1cblxuZnVuY3Rpb24gX2NsYXNzQ2FsbENoZWNrKGluc3RhbmNlLCBDb25zdHJ1Y3RvcikgeyBpZiAoIShpbnN0YW5jZSBpbnN0YW5jZW9mIENvbnN0cnVjdG9yKSkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdDYW5ub3QgY2FsbCBhIGNsYXNzIGFzIGEgZnVuY3Rpb24nKTsgfSB9XG5cbmZ1bmN0aW9uIF9pbmhlcml0cyhzdWJDbGFzcywgc3VwZXJDbGFzcykgeyBpZiAodHlwZW9mIHN1cGVyQ2xhc3MgIT09ICdmdW5jdGlvbicgJiYgc3VwZXJDbGFzcyAhPT0gbnVsbCkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdTdXBlciBleHByZXNzaW9uIG11c3QgZWl0aGVyIGJlIG51bGwgb3IgYSBmdW5jdGlvbiwgbm90ICcgKyB0eXBlb2Ygc3VwZXJDbGFzcyk7IH0gc3ViQ2xhc3MucHJvdG90eXBlID0gT2JqZWN0LmNyZWF0ZShzdXBlckNsYXNzICYmIHN1cGVyQ2xhc3MucHJvdG90eXBlLCB7IGNvbnN0cnVjdG9yOiB7IHZhbHVlOiBzdWJDbGFzcywgZW51bWVyYWJsZTogZmFsc2UsIHdyaXRhYmxlOiB0cnVlLCBjb25maWd1cmFibGU6IHRydWUgfSB9KTsgaWYgKHN1cGVyQ2xhc3MpIE9iamVjdC5zZXRQcm90b3R5cGVPZiA/IE9iamVjdC5zZXRQcm90b3R5cGVPZihzdWJDbGFzcywgc3VwZXJDbGFzcykgOiBzdWJDbGFzcy5fX3Byb3RvX18gPSBzdXBlckNsYXNzOyB9XG5cbnZhciBfZXZlbnRQcm90b3R5cGUgPSByZXF1aXJlKCcuL2V2ZW50LXByb3RvdHlwZScpO1xuXG52YXIgX2V2ZW50UHJvdG90eXBlMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2V2ZW50UHJvdG90eXBlKTtcblxudmFyIENsb3NlRXZlbnQgPSAoZnVuY3Rpb24gKF9FdmVudFByb3RvdHlwZSkge1xuICBfaW5oZXJpdHMoQ2xvc2VFdmVudCwgX0V2ZW50UHJvdG90eXBlKTtcblxuICBmdW5jdGlvbiBDbG9zZUV2ZW50KHR5cGUpIHtcbiAgICB2YXIgZXZlbnRJbml0Q29uZmlnID0gYXJndW1lbnRzLmxlbmd0aCA8PSAxIHx8IGFyZ3VtZW50c1sxXSA9PT0gdW5kZWZpbmVkID8ge30gOiBhcmd1bWVudHNbMV07XG5cbiAgICBfY2xhc3NDYWxsQ2hlY2sodGhpcywgQ2xvc2VFdmVudCk7XG5cbiAgICBfZ2V0KE9iamVjdC5nZXRQcm90b3R5cGVPZihDbG9zZUV2ZW50LnByb3RvdHlwZSksICdjb25zdHJ1Y3RvcicsIHRoaXMpLmNhbGwodGhpcyk7XG5cbiAgICBpZiAoIXR5cGUpIHtcbiAgICAgIHRocm93IG5ldyBUeXBlRXJyb3IoJ0ZhaWxlZCB0byBjb25zdHJ1Y3QgXFwnQ2xvc2VFdmVudFxcJzogMSBhcmd1bWVudCByZXF1aXJlZCwgYnV0IG9ubHkgMCBwcmVzZW50LicpO1xuICAgIH1cblxuICAgIGlmICh0eXBlb2YgZXZlbnRJbml0Q29uZmlnICE9PSAnb2JqZWN0Jykge1xuICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignRmFpbGVkIHRvIGNvbnN0cnVjdCBcXCdDbG9zZUV2ZW50XFwnOiBwYXJhbWV0ZXIgMiAoXFwnZXZlbnRJbml0RGljdFxcJykgaXMgbm90IGFuIG9iamVjdCcpO1xuICAgIH1cblxuICAgIHZhciBidWJibGVzID0gZXZlbnRJbml0Q29uZmlnLmJ1YmJsZXM7XG4gICAgdmFyIGNhbmNlbGFibGUgPSBldmVudEluaXRDb25maWcuY2FuY2VsYWJsZTtcbiAgICB2YXIgY29kZSA9IGV2ZW50SW5pdENvbmZpZy5jb2RlO1xuICAgIHZhciByZWFzb24gPSBldmVudEluaXRDb25maWcucmVhc29uO1xuICAgIHZhciB3YXNDbGVhbiA9IGV2ZW50SW5pdENvbmZpZy53YXNDbGVhbjtcblxuICAgIHRoaXMudHlwZSA9IFN0cmluZyh0eXBlKTtcbiAgICB0aGlzLnRpbWVTdGFtcCA9IERhdGUubm93KCk7XG4gICAgdGhpcy50YXJnZXQgPSBudWxsO1xuICAgIHRoaXMuc3JjRWxlbWVudCA9IG51bGw7XG4gICAgdGhpcy5yZXR1cm5WYWx1ZSA9IHRydWU7XG4gICAgdGhpcy5pc1RydXN0ZWQgPSBmYWxzZTtcbiAgICB0aGlzLmV2ZW50UGhhc2UgPSAwO1xuICAgIHRoaXMuZGVmYXVsdFByZXZlbnRlZCA9IGZhbHNlO1xuICAgIHRoaXMuY3VycmVudFRhcmdldCA9IG51bGw7XG4gICAgdGhpcy5jYW5jZWxhYmxlID0gY2FuY2VsYWJsZSA/IEJvb2xlYW4oY2FuY2VsYWJsZSkgOiBmYWxzZTtcbiAgICB0aGlzLmNhbm5jZWxCdWJibGUgPSBmYWxzZTtcbiAgICB0aGlzLmJ1YmJsZXMgPSBidWJibGVzID8gQm9vbGVhbihidWJibGVzKSA6IGZhbHNlO1xuICAgIHRoaXMuY29kZSA9IHR5cGVvZiBjb2RlID09PSAnbnVtYmVyJyA/IE51bWJlcihjb2RlKSA6IDA7XG4gICAgdGhpcy5yZWFzb24gPSByZWFzb24gPyBTdHJpbmcocmVhc29uKSA6ICcnO1xuICAgIHRoaXMud2FzQ2xlYW4gPSB3YXNDbGVhbiA/IEJvb2xlYW4od2FzQ2xlYW4pIDogZmFsc2U7XG4gIH1cblxuICByZXR1cm4gQ2xvc2VFdmVudDtcbn0pKF9ldmVudFByb3RvdHlwZTJbJ2RlZmF1bHQnXSk7XG5cbmV4cG9ydHNbJ2RlZmF1bHQnXSA9IENsb3NlRXZlbnQ7XG5tb2R1bGUuZXhwb3J0cyA9IGV4cG9ydHNbJ2RlZmF1bHQnXTsiLCIvKlxuKiBUaGlzIGRlbGF5IGFsbG93cyB0aGUgdGhyZWFkIHRvIGZpbmlzaCBhc3NpZ25pbmcgaXRzIG9uKiBtZXRob2RzXG4qIGJlZm9yZSBpbnZva2luZyB0aGUgZGVsYXkgY2FsbGJhY2suIFRoaXMgaXMgcHVyZWx5IGEgdGltaW5nIGhhY2suXG4qIGh0dHA6Ly9nZWVrYWJ5dGUuYmxvZ3Nwb3QuY29tLzIwMTQvMDEvamF2YXNjcmlwdC1lZmZlY3Qtb2Ytc2V0dGluZy1zZXR0aW1lb3V0Lmh0bWxcbipcbiogQHBhcmFtIHtjYWxsYmFjazogZnVuY3Rpb259IHRoZSBjYWxsYmFjayB3aGljaCB3aWxsIGJlIGludm9rZWQgYWZ0ZXIgdGhlIHRpbWVvdXRcbiogQHBhcm1hIHtjb250ZXh0OiBvYmplY3R9IHRoZSBjb250ZXh0IGluIHdoaWNoIHRvIGludm9rZSB0aGUgZnVuY3Rpb25cbiovXG5cInVzZSBzdHJpY3RcIjtcblxuT2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsIFwiX19lc01vZHVsZVwiLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcbmZ1bmN0aW9uIGRlbGF5KGNhbGxiYWNrLCBjb250ZXh0KSB7XG4gIHNldFRpbWVvdXQoZnVuY3Rpb24gdGltZW91dCh0aW1lb3V0Q29udGV4dCkge1xuICAgIGNhbGxiYWNrLmNhbGwodGltZW91dENvbnRleHQpO1xuICB9LCA0LCBjb250ZXh0KTtcbn1cblxuZXhwb3J0c1tcImRlZmF1bHRcIl0gPSBkZWxheTtcbm1vZHVsZS5leHBvcnRzID0gZXhwb3J0c1tcImRlZmF1bHRcIl07IiwiJ3VzZSBzdHJpY3QnO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcblxudmFyIF9jcmVhdGVDbGFzcyA9IChmdW5jdGlvbiAoKSB7IGZ1bmN0aW9uIGRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBwcm9wcykgeyBmb3IgKHZhciBpID0gMDsgaSA8IHByb3BzLmxlbmd0aDsgaSsrKSB7IHZhciBkZXNjcmlwdG9yID0gcHJvcHNbaV07IGRlc2NyaXB0b3IuZW51bWVyYWJsZSA9IGRlc2NyaXB0b3IuZW51bWVyYWJsZSB8fCBmYWxzZTsgZGVzY3JpcHRvci5jb25maWd1cmFibGUgPSB0cnVlOyBpZiAoJ3ZhbHVlJyBpbiBkZXNjcmlwdG9yKSBkZXNjcmlwdG9yLndyaXRhYmxlID0gdHJ1ZTsgT2JqZWN0LmRlZmluZVByb3BlcnR5KHRhcmdldCwgZGVzY3JpcHRvci5rZXksIGRlc2NyaXB0b3IpOyB9IH0gcmV0dXJuIGZ1bmN0aW9uIChDb25zdHJ1Y3RvciwgcHJvdG9Qcm9wcywgc3RhdGljUHJvcHMpIHsgaWYgKHByb3RvUHJvcHMpIGRlZmluZVByb3BlcnRpZXMoQ29uc3RydWN0b3IucHJvdG90eXBlLCBwcm90b1Byb3BzKTsgaWYgKHN0YXRpY1Byb3BzKSBkZWZpbmVQcm9wZXJ0aWVzKENvbnN0cnVjdG9yLCBzdGF0aWNQcm9wcyk7IHJldHVybiBDb25zdHJ1Y3RvcjsgfTsgfSkoKTtcblxuZnVuY3Rpb24gX2NsYXNzQ2FsbENoZWNrKGluc3RhbmNlLCBDb25zdHJ1Y3RvcikgeyBpZiAoIShpbnN0YW5jZSBpbnN0YW5jZW9mIENvbnN0cnVjdG9yKSkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdDYW5ub3QgY2FsbCBhIGNsYXNzIGFzIGEgZnVuY3Rpb24nKTsgfSB9XG5cbnZhciBFdmVudFByb3RvdHlwZSA9IChmdW5jdGlvbiAoKSB7XG4gIGZ1bmN0aW9uIEV2ZW50UHJvdG90eXBlKCkge1xuICAgIF9jbGFzc0NhbGxDaGVjayh0aGlzLCBFdmVudFByb3RvdHlwZSk7XG4gIH1cblxuICBfY3JlYXRlQ2xhc3MoRXZlbnRQcm90b3R5cGUsIFt7XG4gICAga2V5OiAnc3RvcFByb3BhZ2F0aW9uJyxcblxuICAgIC8vIE5vb3BzXG4gICAgdmFsdWU6IGZ1bmN0aW9uIHN0b3BQcm9wYWdhdGlvbigpIHt9XG4gIH0sIHtcbiAgICBrZXk6ICdzdG9wSW1tZWRpYXRlUHJvcGFnYXRpb24nLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBzdG9wSW1tZWRpYXRlUHJvcGFnYXRpb24oKSB7fVxuXG4gICAgLy8gaWYgbm8gYXJndW1lbnRzIGFyZSBwYXNzZWQgdGhlbiB0aGUgdHlwZSBpcyBzZXQgdG8gXCJ1bmRlZmluZWRcIiBvblxuICAgIC8vIGNocm9tZSBhbmQgc2FmYXJpLlxuICB9LCB7XG4gICAga2V5OiAnaW5pdEV2ZW50JyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gaW5pdEV2ZW50KCkge1xuICAgICAgdmFyIHR5cGUgPSBhcmd1bWVudHMubGVuZ3RoIDw9IDAgfHwgYXJndW1lbnRzWzBdID09PSB1bmRlZmluZWQgPyAndW5kZWZpbmVkJyA6IGFyZ3VtZW50c1swXTtcbiAgICAgIHZhciBidWJibGVzID0gYXJndW1lbnRzLmxlbmd0aCA8PSAxIHx8IGFyZ3VtZW50c1sxXSA9PT0gdW5kZWZpbmVkID8gZmFsc2UgOiBhcmd1bWVudHNbMV07XG4gICAgICB2YXIgY2FuY2VsYWJsZSA9IGFyZ3VtZW50cy5sZW5ndGggPD0gMiB8fCBhcmd1bWVudHNbMl0gPT09IHVuZGVmaW5lZCA/IGZhbHNlIDogYXJndW1lbnRzWzJdO1xuXG4gICAgICBPYmplY3QuYXNzaWduKHRoaXMsIHtcbiAgICAgICAgdHlwZTogU3RyaW5nKHR5cGUpLFxuICAgICAgICBidWJibGVzOiBCb29sZWFuKGJ1YmJsZXMpLFxuICAgICAgICBjYW5jZWxhYmxlOiBCb29sZWFuKGNhbmNlbGFibGUpXG4gICAgICB9KTtcbiAgICB9XG4gIH1dKTtcblxuICByZXR1cm4gRXZlbnRQcm90b3R5cGU7XG59KSgpO1xuXG5leHBvcnRzWydkZWZhdWx0J10gPSBFdmVudFByb3RvdHlwZTtcbm1vZHVsZS5leHBvcnRzID0gZXhwb3J0c1snZGVmYXVsdCddOyIsIid1c2Ugc3RyaWN0JztcblxuT2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsICdfX2VzTW9kdWxlJywge1xuICB2YWx1ZTogdHJ1ZVxufSk7XG5cbnZhciBfZ2V0ID0gZnVuY3Rpb24gZ2V0KF94MiwgX3gzLCBfeDQpIHsgdmFyIF9hZ2FpbiA9IHRydWU7IF9mdW5jdGlvbjogd2hpbGUgKF9hZ2FpbikgeyB2YXIgb2JqZWN0ID0gX3gyLCBwcm9wZXJ0eSA9IF94MywgcmVjZWl2ZXIgPSBfeDQ7IF9hZ2FpbiA9IGZhbHNlOyBpZiAob2JqZWN0ID09PSBudWxsKSBvYmplY3QgPSBGdW5jdGlvbi5wcm90b3R5cGU7IHZhciBkZXNjID0gT2JqZWN0LmdldE93blByb3BlcnR5RGVzY3JpcHRvcihvYmplY3QsIHByb3BlcnR5KTsgaWYgKGRlc2MgPT09IHVuZGVmaW5lZCkgeyB2YXIgcGFyZW50ID0gT2JqZWN0LmdldFByb3RvdHlwZU9mKG9iamVjdCk7IGlmIChwYXJlbnQgPT09IG51bGwpIHsgcmV0dXJuIHVuZGVmaW5lZDsgfSBlbHNlIHsgX3gyID0gcGFyZW50OyBfeDMgPSBwcm9wZXJ0eTsgX3g0ID0gcmVjZWl2ZXI7IF9hZ2FpbiA9IHRydWU7IGRlc2MgPSBwYXJlbnQgPSB1bmRlZmluZWQ7IGNvbnRpbnVlIF9mdW5jdGlvbjsgfSB9IGVsc2UgaWYgKCd2YWx1ZScgaW4gZGVzYykgeyByZXR1cm4gZGVzYy52YWx1ZTsgfSBlbHNlIHsgdmFyIGdldHRlciA9IGRlc2MuZ2V0OyBpZiAoZ2V0dGVyID09PSB1bmRlZmluZWQpIHsgcmV0dXJuIHVuZGVmaW5lZDsgfSByZXR1cm4gZ2V0dGVyLmNhbGwocmVjZWl2ZXIpOyB9IH0gfTtcblxuZnVuY3Rpb24gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChvYmopIHsgcmV0dXJuIG9iaiAmJiBvYmouX19lc01vZHVsZSA/IG9iaiA6IHsgJ2RlZmF1bHQnOiBvYmogfTsgfVxuXG5mdW5jdGlvbiBfY2xhc3NDYWxsQ2hlY2soaW5zdGFuY2UsIENvbnN0cnVjdG9yKSB7IGlmICghKGluc3RhbmNlIGluc3RhbmNlb2YgQ29uc3RydWN0b3IpKSB7IHRocm93IG5ldyBUeXBlRXJyb3IoJ0Nhbm5vdCBjYWxsIGEgY2xhc3MgYXMgYSBmdW5jdGlvbicpOyB9IH1cblxuZnVuY3Rpb24gX2luaGVyaXRzKHN1YkNsYXNzLCBzdXBlckNsYXNzKSB7IGlmICh0eXBlb2Ygc3VwZXJDbGFzcyAhPT0gJ2Z1bmN0aW9uJyAmJiBzdXBlckNsYXNzICE9PSBudWxsKSB7IHRocm93IG5ldyBUeXBlRXJyb3IoJ1N1cGVyIGV4cHJlc3Npb24gbXVzdCBlaXRoZXIgYmUgbnVsbCBvciBhIGZ1bmN0aW9uLCBub3QgJyArIHR5cGVvZiBzdXBlckNsYXNzKTsgfSBzdWJDbGFzcy5wcm90b3R5cGUgPSBPYmplY3QuY3JlYXRlKHN1cGVyQ2xhc3MgJiYgc3VwZXJDbGFzcy5wcm90b3R5cGUsIHsgY29uc3RydWN0b3I6IHsgdmFsdWU6IHN1YkNsYXNzLCBlbnVtZXJhYmxlOiBmYWxzZSwgd3JpdGFibGU6IHRydWUsIGNvbmZpZ3VyYWJsZTogdHJ1ZSB9IH0pOyBpZiAoc3VwZXJDbGFzcykgT2JqZWN0LnNldFByb3RvdHlwZU9mID8gT2JqZWN0LnNldFByb3RvdHlwZU9mKHN1YkNsYXNzLCBzdXBlckNsYXNzKSA6IHN1YkNsYXNzLl9fcHJvdG9fXyA9IHN1cGVyQ2xhc3M7IH1cblxudmFyIF9ldmVudFByb3RvdHlwZSA9IHJlcXVpcmUoJy4vZXZlbnQtcHJvdG90eXBlJyk7XG5cbnZhciBfZXZlbnRQcm90b3R5cGUyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfZXZlbnRQcm90b3R5cGUpO1xuXG52YXIgRXZlbnQgPSAoZnVuY3Rpb24gKF9FdmVudFByb3RvdHlwZSkge1xuICBfaW5oZXJpdHMoRXZlbnQsIF9FdmVudFByb3RvdHlwZSk7XG5cbiAgZnVuY3Rpb24gRXZlbnQodHlwZSkge1xuICAgIHZhciBldmVudEluaXRDb25maWcgPSBhcmd1bWVudHMubGVuZ3RoIDw9IDEgfHwgYXJndW1lbnRzWzFdID09PSB1bmRlZmluZWQgPyB7fSA6IGFyZ3VtZW50c1sxXTtcblxuICAgIF9jbGFzc0NhbGxDaGVjayh0aGlzLCBFdmVudCk7XG5cbiAgICBfZ2V0KE9iamVjdC5nZXRQcm90b3R5cGVPZihFdmVudC5wcm90b3R5cGUpLCAnY29uc3RydWN0b3InLCB0aGlzKS5jYWxsKHRoaXMpO1xuXG4gICAgaWYgKCF0eXBlKSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdGYWlsZWQgdG8gY29uc3RydWN0IFxcJ0V2ZW50XFwnOiAxIGFyZ3VtZW50IHJlcXVpcmVkLCBidXQgb25seSAwIHByZXNlbnQuJyk7XG4gICAgfVxuXG4gICAgaWYgKHR5cGVvZiBldmVudEluaXRDb25maWcgIT09ICdvYmplY3QnKSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdGYWlsZWQgdG8gY29uc3RydWN0IFxcJ0V2ZW50XFwnOiBwYXJhbWV0ZXIgMiAoXFwnZXZlbnRJbml0RGljdFxcJykgaXMgbm90IGFuIG9iamVjdCcpO1xuICAgIH1cblxuICAgIHZhciBidWJibGVzID0gZXZlbnRJbml0Q29uZmlnLmJ1YmJsZXM7XG4gICAgdmFyIGNhbmNlbGFibGUgPSBldmVudEluaXRDb25maWcuY2FuY2VsYWJsZTtcblxuICAgIHRoaXMudHlwZSA9IFN0cmluZyh0eXBlKTtcbiAgICB0aGlzLnRpbWVTdGFtcCA9IERhdGUubm93KCk7XG4gICAgdGhpcy50YXJnZXQgPSBudWxsO1xuICAgIHRoaXMuc3JjRWxlbWVudCA9IG51bGw7XG4gICAgdGhpcy5yZXR1cm5WYWx1ZSA9IHRydWU7XG4gICAgdGhpcy5pc1RydXN0ZWQgPSBmYWxzZTtcbiAgICB0aGlzLmV2ZW50UGhhc2UgPSAwO1xuICAgIHRoaXMuZGVmYXVsdFByZXZlbnRlZCA9IGZhbHNlO1xuICAgIHRoaXMuY3VycmVudFRhcmdldCA9IG51bGw7XG4gICAgdGhpcy5jYW5jZWxhYmxlID0gY2FuY2VsYWJsZSA/IEJvb2xlYW4oY2FuY2VsYWJsZSkgOiBmYWxzZTtcbiAgICB0aGlzLmNhbm5jZWxCdWJibGUgPSBmYWxzZTtcbiAgICB0aGlzLmJ1YmJsZXMgPSBidWJibGVzID8gQm9vbGVhbihidWJibGVzKSA6IGZhbHNlO1xuICB9XG5cbiAgcmV0dXJuIEV2ZW50O1xufSkoX2V2ZW50UHJvdG90eXBlMlsnZGVmYXVsdCddKTtcblxuZXhwb3J0c1snZGVmYXVsdCddID0gRXZlbnQ7XG5tb2R1bGUuZXhwb3J0cyA9IGV4cG9ydHNbJ2RlZmF1bHQnXTsiLCIndXNlIHN0cmljdCc7XG5cbk9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHtcbiAgdmFsdWU6IHRydWVcbn0pO1xuXG52YXIgX2dldCA9IGZ1bmN0aW9uIGdldChfeDIsIF94MywgX3g0KSB7IHZhciBfYWdhaW4gPSB0cnVlOyBfZnVuY3Rpb246IHdoaWxlIChfYWdhaW4pIHsgdmFyIG9iamVjdCA9IF94MiwgcHJvcGVydHkgPSBfeDMsIHJlY2VpdmVyID0gX3g0OyBfYWdhaW4gPSBmYWxzZTsgaWYgKG9iamVjdCA9PT0gbnVsbCkgb2JqZWN0ID0gRnVuY3Rpb24ucHJvdG90eXBlOyB2YXIgZGVzYyA9IE9iamVjdC5nZXRPd25Qcm9wZXJ0eURlc2NyaXB0b3Iob2JqZWN0LCBwcm9wZXJ0eSk7IGlmIChkZXNjID09PSB1bmRlZmluZWQpIHsgdmFyIHBhcmVudCA9IE9iamVjdC5nZXRQcm90b3R5cGVPZihvYmplY3QpOyBpZiAocGFyZW50ID09PSBudWxsKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gZWxzZSB7IF94MiA9IHBhcmVudDsgX3gzID0gcHJvcGVydHk7IF94NCA9IHJlY2VpdmVyOyBfYWdhaW4gPSB0cnVlOyBkZXNjID0gcGFyZW50ID0gdW5kZWZpbmVkOyBjb250aW51ZSBfZnVuY3Rpb247IH0gfSBlbHNlIGlmICgndmFsdWUnIGluIGRlc2MpIHsgcmV0dXJuIGRlc2MudmFsdWU7IH0gZWxzZSB7IHZhciBnZXR0ZXIgPSBkZXNjLmdldDsgaWYgKGdldHRlciA9PT0gdW5kZWZpbmVkKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gcmV0dXJuIGdldHRlci5jYWxsKHJlY2VpdmVyKTsgfSB9IH07XG5cbmZ1bmN0aW9uIF9pbnRlcm9wUmVxdWlyZURlZmF1bHQob2JqKSB7IHJldHVybiBvYmogJiYgb2JqLl9fZXNNb2R1bGUgPyBvYmogOiB7ICdkZWZhdWx0Jzogb2JqIH07IH1cblxuZnVuY3Rpb24gX2NsYXNzQ2FsbENoZWNrKGluc3RhbmNlLCBDb25zdHJ1Y3RvcikgeyBpZiAoIShpbnN0YW5jZSBpbnN0YW5jZW9mIENvbnN0cnVjdG9yKSkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdDYW5ub3QgY2FsbCBhIGNsYXNzIGFzIGEgZnVuY3Rpb24nKTsgfSB9XG5cbmZ1bmN0aW9uIF9pbmhlcml0cyhzdWJDbGFzcywgc3VwZXJDbGFzcykgeyBpZiAodHlwZW9mIHN1cGVyQ2xhc3MgIT09ICdmdW5jdGlvbicgJiYgc3VwZXJDbGFzcyAhPT0gbnVsbCkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdTdXBlciBleHByZXNzaW9uIG11c3QgZWl0aGVyIGJlIG51bGwgb3IgYSBmdW5jdGlvbiwgbm90ICcgKyB0eXBlb2Ygc3VwZXJDbGFzcyk7IH0gc3ViQ2xhc3MucHJvdG90eXBlID0gT2JqZWN0LmNyZWF0ZShzdXBlckNsYXNzICYmIHN1cGVyQ2xhc3MucHJvdG90eXBlLCB7IGNvbnN0cnVjdG9yOiB7IHZhbHVlOiBzdWJDbGFzcywgZW51bWVyYWJsZTogZmFsc2UsIHdyaXRhYmxlOiB0cnVlLCBjb25maWd1cmFibGU6IHRydWUgfSB9KTsgaWYgKHN1cGVyQ2xhc3MpIE9iamVjdC5zZXRQcm90b3R5cGVPZiA/IE9iamVjdC5zZXRQcm90b3R5cGVPZihzdWJDbGFzcywgc3VwZXJDbGFzcykgOiBzdWJDbGFzcy5fX3Byb3RvX18gPSBzdXBlckNsYXNzOyB9XG5cbnZhciBfZXZlbnRQcm90b3R5cGUgPSByZXF1aXJlKCcuL2V2ZW50LXByb3RvdHlwZScpO1xuXG52YXIgX2V2ZW50UHJvdG90eXBlMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2V2ZW50UHJvdG90eXBlKTtcblxudmFyIE1lc3NhZ2VFdmVudCA9IChmdW5jdGlvbiAoX0V2ZW50UHJvdG90eXBlKSB7XG4gIF9pbmhlcml0cyhNZXNzYWdlRXZlbnQsIF9FdmVudFByb3RvdHlwZSk7XG5cbiAgZnVuY3Rpb24gTWVzc2FnZUV2ZW50KHR5cGUpIHtcbiAgICB2YXIgZXZlbnRJbml0Q29uZmlnID0gYXJndW1lbnRzLmxlbmd0aCA8PSAxIHx8IGFyZ3VtZW50c1sxXSA9PT0gdW5kZWZpbmVkID8ge30gOiBhcmd1bWVudHNbMV07XG5cbiAgICBfY2xhc3NDYWxsQ2hlY2sodGhpcywgTWVzc2FnZUV2ZW50KTtcblxuICAgIF9nZXQoT2JqZWN0LmdldFByb3RvdHlwZU9mKE1lc3NhZ2VFdmVudC5wcm90b3R5cGUpLCAnY29uc3RydWN0b3InLCB0aGlzKS5jYWxsKHRoaXMpO1xuXG4gICAgaWYgKCF0eXBlKSB7XG4gICAgICB0aHJvdyBuZXcgVHlwZUVycm9yKCdGYWlsZWQgdG8gY29uc3RydWN0IFxcJ01lc3NhZ2VFdmVudFxcJzogMSBhcmd1bWVudCByZXF1aXJlZCwgYnV0IG9ubHkgMCBwcmVzZW50LicpO1xuICAgIH1cblxuICAgIGlmICh0eXBlb2YgZXZlbnRJbml0Q29uZmlnICE9PSAnb2JqZWN0Jykge1xuICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignRmFpbGVkIHRvIGNvbnN0cnVjdCBcXCdNZXNzYWdlRXZlbnRcXCc6IHBhcmFtZXRlciAyIChcXCdldmVudEluaXREaWN0XFwnKSBpcyBub3QgYW4gb2JqZWN0Jyk7XG4gICAgfVxuXG4gICAgdmFyIGJ1YmJsZXMgPSBldmVudEluaXRDb25maWcuYnViYmxlcztcbiAgICB2YXIgY2FuY2VsYWJsZSA9IGV2ZW50SW5pdENvbmZpZy5jYW5jZWxhYmxlO1xuICAgIHZhciBkYXRhID0gZXZlbnRJbml0Q29uZmlnLmRhdGE7XG4gICAgdmFyIG9yaWdpbiA9IGV2ZW50SW5pdENvbmZpZy5vcmlnaW47XG4gICAgdmFyIGxhc3RFdmVudElkID0gZXZlbnRJbml0Q29uZmlnLmxhc3RFdmVudElkO1xuICAgIHZhciBwb3J0cyA9IGV2ZW50SW5pdENvbmZpZy5wb3J0cztcblxuICAgIHRoaXMudHlwZSA9IFN0cmluZyh0eXBlKTtcbiAgICB0aGlzLnRpbWVTdGFtcCA9IERhdGUubm93KCk7XG4gICAgdGhpcy50YXJnZXQgPSBudWxsO1xuICAgIHRoaXMuc3JjRWxlbWVudCA9IG51bGw7XG4gICAgdGhpcy5yZXR1cm5WYWx1ZSA9IHRydWU7XG4gICAgdGhpcy5pc1RydXN0ZWQgPSBmYWxzZTtcbiAgICB0aGlzLmV2ZW50UGhhc2UgPSAwO1xuICAgIHRoaXMuZGVmYXVsdFByZXZlbnRlZCA9IGZhbHNlO1xuICAgIHRoaXMuY3VycmVudFRhcmdldCA9IG51bGw7XG4gICAgdGhpcy5jYW5jZWxhYmxlID0gY2FuY2VsYWJsZSA/IEJvb2xlYW4oY2FuY2VsYWJsZSkgOiBmYWxzZTtcbiAgICB0aGlzLmNhbm5jZWxCdWJibGUgPSBmYWxzZTtcbiAgICB0aGlzLmJ1YmJsZXMgPSBidWJibGVzID8gQm9vbGVhbihidWJibGVzKSA6IGZhbHNlO1xuICAgIHRoaXMub3JpZ2luID0gb3JpZ2luID8gU3RyaW5nKG9yaWdpbikgOiAnJztcbiAgICB0aGlzLnBvcnRzID0gdHlwZW9mIHBvcnRzID09PSAndW5kZWZpbmVkJyA/IG51bGwgOiBwb3J0cztcbiAgICB0aGlzLmRhdGEgPSB0eXBlb2YgZGF0YSA9PT0gJ3VuZGVmaW5lZCcgPyBudWxsIDogZGF0YTtcbiAgICB0aGlzLmxhc3RFdmVudElkID0gbGFzdEV2ZW50SWQgPyBTdHJpbmcobGFzdEV2ZW50SWQpIDogJyc7XG4gIH1cblxuICByZXR1cm4gTWVzc2FnZUV2ZW50O1xufSkoX2V2ZW50UHJvdG90eXBlMlsnZGVmYXVsdCddKTtcblxuZXhwb3J0c1snZGVmYXVsdCddID0gTWVzc2FnZUV2ZW50O1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzWydkZWZhdWx0J107IiwiJ3VzZSBzdHJpY3QnO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcblxuZnVuY3Rpb24gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChvYmopIHsgcmV0dXJuIG9iaiAmJiBvYmouX19lc01vZHVsZSA/IG9iaiA6IHsgJ2RlZmF1bHQnOiBvYmogfTsgfVxuXG52YXIgX3NlcnZlciA9IHJlcXVpcmUoJy4vc2VydmVyJyk7XG5cbnZhciBfc2VydmVyMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX3NlcnZlcik7XG5cbnZhciBfc29ja2V0SW8gPSByZXF1aXJlKCcuL3NvY2tldC1pbycpO1xuXG52YXIgX3NvY2tldElvMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX3NvY2tldElvKTtcblxudmFyIF93ZWJzb2NrZXQgPSByZXF1aXJlKCcuL3dlYnNvY2tldCcpO1xuXG52YXIgX3dlYnNvY2tldDIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF93ZWJzb2NrZXQpO1xuXG5pZiAodHlwZW9mIHdpbmRvdyAhPT0gJ3VuZGVmaW5lZCcpIHtcbiAgd2luZG93Lk1vY2tTZXJ2ZXIgPSBfc2VydmVyMlsnZGVmYXVsdCddO1xuICB3aW5kb3cuTW9ja1dlYlNvY2tldCA9IF93ZWJzb2NrZXQyWydkZWZhdWx0J107XG4gIHdpbmRvdy5Nb2NrU29ja2V0SU8gPSBfc29ja2V0SW8yWydkZWZhdWx0J107XG59XG5cbnZhciBTZXJ2ZXIgPSBfc2VydmVyMlsnZGVmYXVsdCddO1xuZXhwb3J0cy5TZXJ2ZXIgPSBTZXJ2ZXI7XG52YXIgV2ViU29ja2V0ID0gX3dlYnNvY2tldDJbJ2RlZmF1bHQnXTtcbmV4cG9ydHMuV2ViU29ja2V0ID0gV2ViU29ja2V0O1xudmFyIFNvY2tldElPID0gX3NvY2tldElvMlsnZGVmYXVsdCddO1xuZXhwb3J0cy5Tb2NrZXRJTyA9IFNvY2tldElPOyIsIid1c2Ugc3RyaWN0JztcblxuT2JqZWN0LmRlZmluZVByb3BlcnR5KGV4cG9ydHMsICdfX2VzTW9kdWxlJywge1xuICB2YWx1ZTogdHJ1ZVxufSk7XG5cbnZhciBfY3JlYXRlQ2xhc3MgPSAoZnVuY3Rpb24gKCkgeyBmdW5jdGlvbiBkZWZpbmVQcm9wZXJ0aWVzKHRhcmdldCwgcHJvcHMpIHsgZm9yICh2YXIgaSA9IDA7IGkgPCBwcm9wcy5sZW5ndGg7IGkrKykgeyB2YXIgZGVzY3JpcHRvciA9IHByb3BzW2ldOyBkZXNjcmlwdG9yLmVudW1lcmFibGUgPSBkZXNjcmlwdG9yLmVudW1lcmFibGUgfHwgZmFsc2U7IGRlc2NyaXB0b3IuY29uZmlndXJhYmxlID0gdHJ1ZTsgaWYgKCd2YWx1ZScgaW4gZGVzY3JpcHRvcikgZGVzY3JpcHRvci53cml0YWJsZSA9IHRydWU7IE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGRlc2NyaXB0b3Iua2V5LCBkZXNjcmlwdG9yKTsgfSB9IHJldHVybiBmdW5jdGlvbiAoQ29uc3RydWN0b3IsIHByb3RvUHJvcHMsIHN0YXRpY1Byb3BzKSB7IGlmIChwcm90b1Byb3BzKSBkZWZpbmVQcm9wZXJ0aWVzKENvbnN0cnVjdG9yLnByb3RvdHlwZSwgcHJvdG9Qcm9wcyk7IGlmIChzdGF0aWNQcm9wcykgZGVmaW5lUHJvcGVydGllcyhDb25zdHJ1Y3Rvciwgc3RhdGljUHJvcHMpOyByZXR1cm4gQ29uc3RydWN0b3I7IH07IH0pKCk7XG5cbmZ1bmN0aW9uIF9jbGFzc0NhbGxDaGVjayhpbnN0YW5jZSwgQ29uc3RydWN0b3IpIHsgaWYgKCEoaW5zdGFuY2UgaW5zdGFuY2VvZiBDb25zdHJ1Y3RvcikpIHsgdGhyb3cgbmV3IFR5cGVFcnJvcignQ2Fubm90IGNhbGwgYSBjbGFzcyBhcyBhIGZ1bmN0aW9uJyk7IH0gfVxuXG52YXIgX2hlbHBlcnNBcnJheUhlbHBlcnMgPSByZXF1aXJlKCcuL2hlbHBlcnMvYXJyYXktaGVscGVycycpO1xuXG4vKlxuKiBUaGUgbmV0d29yayBicmlkZ2UgaXMgYSB3YXkgZm9yIHRoZSBtb2NrIHdlYnNvY2tldCBvYmplY3QgdG8gJ2NvbW11bmljYXRlJyB3aXRoXG4qIGFsbCBhdmFsaWJsZSBzZXJ2ZXJzLiBUaGlzIGlzIGEgc2luZ2xldG9uIG9iamVjdCBzbyBpdCBpcyBpbXBvcnRhbnQgdGhhdCB5b3VcbiogY2xlYW4gdXAgdXJsTWFwIHdoZW5ldmVyIHlvdSBhcmUgZmluaXNoZWQuXG4qL1xuXG52YXIgTmV0d29ya0JyaWRnZSA9IChmdW5jdGlvbiAoKSB7XG4gIGZ1bmN0aW9uIE5ldHdvcmtCcmlkZ2UoKSB7XG4gICAgX2NsYXNzQ2FsbENoZWNrKHRoaXMsIE5ldHdvcmtCcmlkZ2UpO1xuXG4gICAgdGhpcy51cmxNYXAgPSB7fTtcbiAgfVxuXG4gIC8qXG4gICogQXR0YWNoZXMgYSB3ZWJzb2NrZXQgb2JqZWN0IHRvIHRoZSB1cmxNYXAgaGFzaCBzbyB0aGF0IGl0IGNhbiBmaW5kIHRoZSBzZXJ2ZXJcbiAgKiBpdCBpcyBjb25uZWN0ZWQgdG8gYW5kIHRoZSBzZXJ2ZXIgaW4gdHVybiBjYW4gZmluZCBpdC5cbiAgKlxuICAqIEBwYXJhbSB7b2JqZWN0fSB3ZWJzb2NrZXQgLSB3ZWJzb2NrZXQgb2JqZWN0IHRvIGFkZCB0byB0aGUgdXJsTWFwIGhhc2hcbiAgKiBAcGFyYW0ge3N0cmluZ30gdXJsXG4gICovXG5cbiAgX2NyZWF0ZUNsYXNzKE5ldHdvcmtCcmlkZ2UsIFt7XG4gICAga2V5OiAnYXR0YWNoV2ViU29ja2V0JyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gYXR0YWNoV2ViU29ja2V0KHdlYnNvY2tldCwgdXJsKSB7XG4gICAgICB2YXIgY29ubmVjdGlvbkxvb2t1cCA9IHRoaXMudXJsTWFwW3VybF07XG5cbiAgICAgIGlmIChjb25uZWN0aW9uTG9va3VwICYmIGNvbm5lY3Rpb25Mb29rdXAuc2VydmVyICYmIGNvbm5lY3Rpb25Mb29rdXAud2Vic29ja2V0cy5pbmRleE9mKHdlYnNvY2tldCkgPT09IC0xKSB7XG4gICAgICAgIGNvbm5lY3Rpb25Mb29rdXAud2Vic29ja2V0cy5wdXNoKHdlYnNvY2tldCk7XG4gICAgICAgIHJldHVybiBjb25uZWN0aW9uTG9va3VwLnNlcnZlcjtcbiAgICAgIH1cbiAgICB9XG5cbiAgICAvKlxuICAgICogQXR0YWNoZXMgYSB3ZWJzb2NrZXQgdG8gYSByb29tXG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ2FkZE1lbWJlcnNoaXBUb1Jvb20nLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBhZGRNZW1iZXJzaGlwVG9Sb29tKHdlYnNvY2tldCwgcm9vbSkge1xuICAgICAgdmFyIGNvbm5lY3Rpb25Mb29rdXAgPSB0aGlzLnVybE1hcFt3ZWJzb2NrZXQudXJsXTtcblxuICAgICAgaWYgKGNvbm5lY3Rpb25Mb29rdXAgJiYgY29ubmVjdGlvbkxvb2t1cC5zZXJ2ZXIgJiYgY29ubmVjdGlvbkxvb2t1cC53ZWJzb2NrZXRzLmluZGV4T2Yod2Vic29ja2V0KSAhPT0gLTEpIHtcbiAgICAgICAgaWYgKCFjb25uZWN0aW9uTG9va3VwLnJvb21NZW1iZXJzaGlwc1tyb29tXSkge1xuICAgICAgICAgIGNvbm5lY3Rpb25Mb29rdXAucm9vbU1lbWJlcnNoaXBzW3Jvb21dID0gW107XG4gICAgICAgIH1cblxuICAgICAgICBjb25uZWN0aW9uTG9va3VwLnJvb21NZW1iZXJzaGlwc1tyb29tXS5wdXNoKHdlYnNvY2tldCk7XG4gICAgICB9XG4gICAgfVxuXG4gICAgLypcbiAgICAqIEF0dGFjaGVzIGEgc2VydmVyIG9iamVjdCB0byB0aGUgdXJsTWFwIGhhc2ggc28gdGhhdCBpdCBjYW4gZmluZCBhIHdlYnNvY2tldHNcbiAgICAqIHdoaWNoIGFyZSBjb25uZWN0ZWQgdG8gaXQgYW5kIHNvIHRoYXQgd2Vic29ja2V0cyBjYW4gaW4gdHVybiBjYW4gZmluZCBpdC5cbiAgICAqXG4gICAgKiBAcGFyYW0ge29iamVjdH0gc2VydmVyIC0gc2VydmVyIG9iamVjdCB0byBhZGQgdG8gdGhlIHVybE1hcCBoYXNoXG4gICAgKiBAcGFyYW0ge3N0cmluZ30gdXJsXG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ2F0dGFjaFNlcnZlcicsXG4gICAgdmFsdWU6IGZ1bmN0aW9uIGF0dGFjaFNlcnZlcihzZXJ2ZXIsIHVybCkge1xuICAgICAgdmFyIGNvbm5lY3Rpb25Mb29rdXAgPSB0aGlzLnVybE1hcFt1cmxdO1xuXG4gICAgICBpZiAoIWNvbm5lY3Rpb25Mb29rdXApIHtcbiAgICAgICAgdGhpcy51cmxNYXBbdXJsXSA9IHtcbiAgICAgICAgICBzZXJ2ZXI6IHNlcnZlcixcbiAgICAgICAgICB3ZWJzb2NrZXRzOiBbXSxcbiAgICAgICAgICByb29tTWVtYmVyc2hpcHM6IHt9XG4gICAgICAgIH07XG5cbiAgICAgICAgcmV0dXJuIHNlcnZlcjtcbiAgICAgIH1cbiAgICB9XG5cbiAgICAvKlxuICAgICogRmluZHMgdGhlIHNlcnZlciB3aGljaCBpcyAncnVubmluZycgb24gdGhlIGdpdmVuIHVybC5cbiAgICAqXG4gICAgKiBAcGFyYW0ge3N0cmluZ30gdXJsIC0gdGhlIHVybCB0byB1c2UgdG8gZmluZCB3aGljaCBzZXJ2ZXIgaXMgcnVubmluZyBvbiBpdFxuICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdzZXJ2ZXJMb29rdXAnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBzZXJ2ZXJMb29rdXAodXJsKSB7XG4gICAgICB2YXIgY29ubmVjdGlvbkxvb2t1cCA9IHRoaXMudXJsTWFwW3VybF07XG5cbiAgICAgIGlmIChjb25uZWN0aW9uTG9va3VwKSB7XG4gICAgICAgIHJldHVybiBjb25uZWN0aW9uTG9va3VwLnNlcnZlcjtcbiAgICAgIH1cbiAgICB9XG5cbiAgICAvKlxuICAgICogRmluZHMgYWxsIHdlYnNvY2tldHMgd2hpY2ggaXMgJ2xpc3RlbmluZycgb24gdGhlIGdpdmVuIHVybC5cbiAgICAqXG4gICAgKiBAcGFyYW0ge3N0cmluZ30gdXJsIC0gdGhlIHVybCB0byB1c2UgdG8gZmluZCBhbGwgd2Vic29ja2V0cyB3aGljaCBhcmUgYXNzb2NpYXRlZCB3aXRoIGl0XG4gICAgKiBAcGFyYW0ge3N0cmluZ30gcm9vbSAtIGlmIGEgcm9vbSBpcyBwcm92aWRlZCwgd2lsbCBvbmx5IHJldHVybiBzb2NrZXRzIGluIHRoaXMgcm9vbVxuICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICd3ZWJzb2NrZXRzTG9va3VwJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gd2Vic29ja2V0c0xvb2t1cCh1cmwsIHJvb20pIHtcbiAgICAgIHZhciBjb25uZWN0aW9uTG9va3VwID0gdGhpcy51cmxNYXBbdXJsXTtcblxuICAgICAgaWYgKCFjb25uZWN0aW9uTG9va3VwKSB7XG4gICAgICAgIHJldHVybiBbXTtcbiAgICAgIH1cblxuICAgICAgaWYgKHJvb20pIHtcbiAgICAgICAgdmFyIG1lbWJlcnMgPSBjb25uZWN0aW9uTG9va3VwLnJvb21NZW1iZXJzaGlwc1tyb29tXTtcbiAgICAgICAgcmV0dXJuIG1lbWJlcnMgPyBtZW1iZXJzIDogW107XG4gICAgICB9XG5cbiAgICAgIHJldHVybiBjb25uZWN0aW9uTG9va3VwLndlYnNvY2tldHM7XG4gICAgfVxuXG4gICAgLypcbiAgICAqIFJlbW92ZXMgdGhlIGVudHJ5IGFzc29jaWF0ZWQgd2l0aCB0aGUgdXJsLlxuICAgICpcbiAgICAqIEBwYXJhbSB7c3RyaW5nfSB1cmxcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAncmVtb3ZlU2VydmVyJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gcmVtb3ZlU2VydmVyKHVybCkge1xuICAgICAgZGVsZXRlIHRoaXMudXJsTWFwW3VybF07XG4gICAgfVxuXG4gICAgLypcbiAgICAqIFJlbW92ZXMgdGhlIGluZGl2aWR1YWwgd2Vic29ja2V0IGZyb20gdGhlIG1hcCBvZiBhc3NvY2lhdGVkIHdlYnNvY2tldHMuXG4gICAgKlxuICAgICogQHBhcmFtIHtvYmplY3R9IHdlYnNvY2tldCAtIHdlYnNvY2tldCBvYmplY3QgdG8gcmVtb3ZlIGZyb20gdGhlIHVybCBtYXBcbiAgICAqIEBwYXJhbSB7c3RyaW5nfSB1cmxcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAncmVtb3ZlV2ViU29ja2V0JyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gcmVtb3ZlV2ViU29ja2V0KHdlYnNvY2tldCwgdXJsKSB7XG4gICAgICB2YXIgY29ubmVjdGlvbkxvb2t1cCA9IHRoaXMudXJsTWFwW3VybF07XG5cbiAgICAgIGlmIChjb25uZWN0aW9uTG9va3VwKSB7XG4gICAgICAgIGNvbm5lY3Rpb25Mb29rdXAud2Vic29ja2V0cyA9ICgwLCBfaGVscGVyc0FycmF5SGVscGVycy5yZWplY3QpKGNvbm5lY3Rpb25Mb29rdXAud2Vic29ja2V0cywgZnVuY3Rpb24gKHNvY2tldCkge1xuICAgICAgICAgIHJldHVybiBzb2NrZXQgPT09IHdlYnNvY2tldDtcbiAgICAgICAgfSk7XG4gICAgICB9XG4gICAgfVxuXG4gICAgLypcbiAgICAqIFJlbW92ZXMgYSB3ZWJzb2NrZXQgZnJvbSBhIHJvb21cbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAncmVtb3ZlTWVtYmVyc2hpcEZyb21Sb29tJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gcmVtb3ZlTWVtYmVyc2hpcEZyb21Sb29tKHdlYnNvY2tldCwgcm9vbSkge1xuICAgICAgdmFyIGNvbm5lY3Rpb25Mb29rdXAgPSB0aGlzLnVybE1hcFt3ZWJzb2NrZXQudXJsXTtcbiAgICAgIHZhciBtZW1iZXJzaGlwcyA9IGNvbm5lY3Rpb25Mb29rdXAucm9vbU1lbWJlcnNoaXBzW3Jvb21dO1xuXG4gICAgICBpZiAoY29ubmVjdGlvbkxvb2t1cCAmJiBtZW1iZXJzaGlwcyAhPT0gbnVsbCkge1xuICAgICAgICBjb25uZWN0aW9uTG9va3VwLnJvb21NZW1iZXJzaGlwc1tyb29tXSA9ICgwLCBfaGVscGVyc0FycmF5SGVscGVycy5yZWplY3QpKG1lbWJlcnNoaXBzLCBmdW5jdGlvbiAoc29ja2V0KSB7XG4gICAgICAgICAgcmV0dXJuIHNvY2tldCA9PT0gd2Vic29ja2V0O1xuICAgICAgICB9KTtcbiAgICAgIH1cbiAgICB9XG4gIH1dKTtcblxuICByZXR1cm4gTmV0d29ya0JyaWRnZTtcbn0pKCk7XG5cbmV4cG9ydHNbJ2RlZmF1bHQnXSA9IG5ldyBOZXR3b3JrQnJpZGdlKCk7XG4vLyBOb3RlOiB0aGlzIGlzIGEgc2luZ2xldG9uXG5tb2R1bGUuZXhwb3J0cyA9IGV4cG9ydHNbJ2RlZmF1bHQnXTsiLCIndXNlIHN0cmljdCc7XG5cbk9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHtcbiAgdmFsdWU6IHRydWVcbn0pO1xuXG52YXIgX2NyZWF0ZUNsYXNzID0gKGZ1bmN0aW9uICgpIHsgZnVuY3Rpb24gZGVmaW5lUHJvcGVydGllcyh0YXJnZXQsIHByb3BzKSB7IGZvciAodmFyIGkgPSAwOyBpIDwgcHJvcHMubGVuZ3RoOyBpKyspIHsgdmFyIGRlc2NyaXB0b3IgPSBwcm9wc1tpXTsgZGVzY3JpcHRvci5lbnVtZXJhYmxlID0gZGVzY3JpcHRvci5lbnVtZXJhYmxlIHx8IGZhbHNlOyBkZXNjcmlwdG9yLmNvbmZpZ3VyYWJsZSA9IHRydWU7IGlmICgndmFsdWUnIGluIGRlc2NyaXB0b3IpIGRlc2NyaXB0b3Iud3JpdGFibGUgPSB0cnVlOyBPYmplY3QuZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBkZXNjcmlwdG9yLmtleSwgZGVzY3JpcHRvcik7IH0gfSByZXR1cm4gZnVuY3Rpb24gKENvbnN0cnVjdG9yLCBwcm90b1Byb3BzLCBzdGF0aWNQcm9wcykgeyBpZiAocHJvdG9Qcm9wcykgZGVmaW5lUHJvcGVydGllcyhDb25zdHJ1Y3Rvci5wcm90b3R5cGUsIHByb3RvUHJvcHMpOyBpZiAoc3RhdGljUHJvcHMpIGRlZmluZVByb3BlcnRpZXMoQ29uc3RydWN0b3IsIHN0YXRpY1Byb3BzKTsgcmV0dXJuIENvbnN0cnVjdG9yOyB9OyB9KSgpO1xuXG52YXIgX2dldCA9IGZ1bmN0aW9uIGdldChfeDQsIF94NSwgX3g2KSB7IHZhciBfYWdhaW4gPSB0cnVlOyBfZnVuY3Rpb246IHdoaWxlIChfYWdhaW4pIHsgdmFyIG9iamVjdCA9IF94NCwgcHJvcGVydHkgPSBfeDUsIHJlY2VpdmVyID0gX3g2OyBfYWdhaW4gPSBmYWxzZTsgaWYgKG9iamVjdCA9PT0gbnVsbCkgb2JqZWN0ID0gRnVuY3Rpb24ucHJvdG90eXBlOyB2YXIgZGVzYyA9IE9iamVjdC5nZXRPd25Qcm9wZXJ0eURlc2NyaXB0b3Iob2JqZWN0LCBwcm9wZXJ0eSk7IGlmIChkZXNjID09PSB1bmRlZmluZWQpIHsgdmFyIHBhcmVudCA9IE9iamVjdC5nZXRQcm90b3R5cGVPZihvYmplY3QpOyBpZiAocGFyZW50ID09PSBudWxsKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gZWxzZSB7IF94NCA9IHBhcmVudDsgX3g1ID0gcHJvcGVydHk7IF94NiA9IHJlY2VpdmVyOyBfYWdhaW4gPSB0cnVlOyBkZXNjID0gcGFyZW50ID0gdW5kZWZpbmVkOyBjb250aW51ZSBfZnVuY3Rpb247IH0gfSBlbHNlIGlmICgndmFsdWUnIGluIGRlc2MpIHsgcmV0dXJuIGRlc2MudmFsdWU7IH0gZWxzZSB7IHZhciBnZXR0ZXIgPSBkZXNjLmdldDsgaWYgKGdldHRlciA9PT0gdW5kZWZpbmVkKSB7IHJldHVybiB1bmRlZmluZWQ7IH0gcmV0dXJuIGdldHRlci5jYWxsKHJlY2VpdmVyKTsgfSB9IH07XG5cbmZ1bmN0aW9uIF9pbnRlcm9wUmVxdWlyZURlZmF1bHQob2JqKSB7IHJldHVybiBvYmogJiYgb2JqLl9fZXNNb2R1bGUgPyBvYmogOiB7ICdkZWZhdWx0Jzogb2JqIH07IH1cblxuZnVuY3Rpb24gX2NsYXNzQ2FsbENoZWNrKGluc3RhbmNlLCBDb25zdHJ1Y3RvcikgeyBpZiAoIShpbnN0YW5jZSBpbnN0YW5jZW9mIENvbnN0cnVjdG9yKSkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdDYW5ub3QgY2FsbCBhIGNsYXNzIGFzIGEgZnVuY3Rpb24nKTsgfSB9XG5cbmZ1bmN0aW9uIF9pbmhlcml0cyhzdWJDbGFzcywgc3VwZXJDbGFzcykgeyBpZiAodHlwZW9mIHN1cGVyQ2xhc3MgIT09ICdmdW5jdGlvbicgJiYgc3VwZXJDbGFzcyAhPT0gbnVsbCkgeyB0aHJvdyBuZXcgVHlwZUVycm9yKCdTdXBlciBleHByZXNzaW9uIG11c3QgZWl0aGVyIGJlIG51bGwgb3IgYSBmdW5jdGlvbiwgbm90ICcgKyB0eXBlb2Ygc3VwZXJDbGFzcyk7IH0gc3ViQ2xhc3MucHJvdG90eXBlID0gT2JqZWN0LmNyZWF0ZShzdXBlckNsYXNzICYmIHN1cGVyQ2xhc3MucHJvdG90eXBlLCB7IGNvbnN0cnVjdG9yOiB7IHZhbHVlOiBzdWJDbGFzcywgZW51bWVyYWJsZTogZmFsc2UsIHdyaXRhYmxlOiB0cnVlLCBjb25maWd1cmFibGU6IHRydWUgfSB9KTsgaWYgKHN1cGVyQ2xhc3MpIE9iamVjdC5zZXRQcm90b3R5cGVPZiA/IE9iamVjdC5zZXRQcm90b3R5cGVPZihzdWJDbGFzcywgc3VwZXJDbGFzcykgOiBzdWJDbGFzcy5fX3Byb3RvX18gPSBzdXBlckNsYXNzOyB9XG5cbnZhciBfdXJpanMgPSByZXF1aXJlKCd1cmlqcycpO1xuXG52YXIgX3VyaWpzMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX3VyaWpzKTtcblxudmFyIF93ZWJzb2NrZXQgPSByZXF1aXJlKCcuL3dlYnNvY2tldCcpO1xuXG52YXIgX3dlYnNvY2tldDIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF93ZWJzb2NrZXQpO1xuXG52YXIgX2V2ZW50VGFyZ2V0ID0gcmVxdWlyZSgnLi9ldmVudC10YXJnZXQnKTtcblxudmFyIF9ldmVudFRhcmdldDIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF9ldmVudFRhcmdldCk7XG5cbnZhciBfbmV0d29ya0JyaWRnZSA9IHJlcXVpcmUoJy4vbmV0d29yay1icmlkZ2UnKTtcblxudmFyIF9uZXR3b3JrQnJpZGdlMiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX25ldHdvcmtCcmlkZ2UpO1xuXG52YXIgX2hlbHBlcnNDbG9zZUNvZGVzID0gcmVxdWlyZSgnLi9oZWxwZXJzL2Nsb3NlLWNvZGVzJyk7XG5cbnZhciBfaGVscGVyc0Nsb3NlQ29kZXMyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfaGVscGVyc0Nsb3NlQ29kZXMpO1xuXG52YXIgX2V2ZW50RmFjdG9yeSA9IHJlcXVpcmUoJy4vZXZlbnQtZmFjdG9yeScpO1xuXG4vKlxuKiBodHRwczovL2dpdGh1Yi5jb20vd2Vic29ja2V0cy93cyNzZXJ2ZXItZXhhbXBsZVxuKi9cblxudmFyIFNlcnZlciA9IChmdW5jdGlvbiAoX0V2ZW50VGFyZ2V0KSB7XG4gIF9pbmhlcml0cyhTZXJ2ZXIsIF9FdmVudFRhcmdldCk7XG5cbiAgLypcbiAgKiBAcGFyYW0ge3N0cmluZ30gdXJsXG4gICovXG5cbiAgZnVuY3Rpb24gU2VydmVyKHVybCkge1xuICAgIF9jbGFzc0NhbGxDaGVjayh0aGlzLCBTZXJ2ZXIpO1xuXG4gICAgX2dldChPYmplY3QuZ2V0UHJvdG90eXBlT2YoU2VydmVyLnByb3RvdHlwZSksICdjb25zdHJ1Y3RvcicsIHRoaXMpLmNhbGwodGhpcyk7XG4gICAgdGhpcy51cmwgPSAoMCwgX3VyaWpzMlsnZGVmYXVsdCddKSh1cmwpLnRvU3RyaW5nKCk7XG4gICAgdmFyIHNlcnZlciA9IF9uZXR3b3JrQnJpZGdlMlsnZGVmYXVsdCddLmF0dGFjaFNlcnZlcih0aGlzLCB0aGlzLnVybCk7XG5cbiAgICBpZiAoIXNlcnZlcikge1xuICAgICAgdGhpcy5kaXNwYXRjaEV2ZW50KCgwLCBfZXZlbnRGYWN0b3J5LmNyZWF0ZUV2ZW50KSh7IHR5cGU6ICdlcnJvcicgfSkpO1xuICAgICAgdGhyb3cgbmV3IEVycm9yKCdBIG1vY2sgc2VydmVyIGlzIGFscmVhZHkgbGlzdGVuaW5nIG9uIHRoaXMgdXJsJyk7XG4gICAgfVxuICB9XG5cbiAgLypcbiAgICogQWx0ZXJuYXRpdmUgY29uc3RydWN0b3IgdG8gc3VwcG9ydCBuYW1lc3BhY2VzIGluIHNvY2tldC5pb1xuICAgKlxuICAgKiBodHRwOi8vc29ja2V0LmlvL2RvY3Mvcm9vbXMtYW5kLW5hbWVzcGFjZXMvI2N1c3RvbS1uYW1lc3BhY2VzXG4gICAqL1xuXG4gIC8qXG4gICogVGhpcyBpcyB0aGUgbWFpbiBmdW5jdGlvbiBmb3IgdGhlIG1vY2sgc2VydmVyIHRvIHN1YnNjcmliZSB0byB0aGUgb24gZXZlbnRzLlxuICAqXG4gICogaWU6IG1vY2tTZXJ2ZXIub24oJ2Nvbm5lY3Rpb24nLCBmdW5jdGlvbigpIHsgY29uc29sZS5sb2coJ2EgbW9jayBjbGllbnQgY29ubmVjdGVkJyk7IH0pO1xuICAqXG4gICogQHBhcmFtIHtzdHJpbmd9IHR5cGUgLSBUaGUgZXZlbnQga2V5IHRvIHN1YnNjcmliZSB0by4gVmFsaWQga2V5cyBhcmU6IGNvbm5lY3Rpb24sIG1lc3NhZ2UsIGFuZCBjbG9zZS5cbiAgKiBAcGFyYW0ge2Z1bmN0aW9ufSBjYWxsYmFjayAtIFRoZSBjYWxsYmFjayB3aGljaCBzaG91bGQgYmUgY2FsbGVkIHdoZW4gYSBjZXJ0YWluIGV2ZW50IGlzIGZpcmVkLlxuICAqL1xuXG4gIF9jcmVhdGVDbGFzcyhTZXJ2ZXIsIFt7XG4gICAga2V5OiAnb24nLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBvbih0eXBlLCBjYWxsYmFjaykge1xuICAgICAgdGhpcy5hZGRFdmVudExpc3RlbmVyKHR5cGUsIGNhbGxiYWNrKTtcbiAgICB9XG5cbiAgICAvKlxuICAgICogVGhpcyBzZW5kIGZ1bmN0aW9uIHdpbGwgbm90aWZ5IGFsbCBtb2NrIGNsaWVudHMgdmlhIHRoZWlyIG9ubWVzc2FnZSBjYWxsYmFja3MgdGhhdCB0aGUgc2VydmVyXG4gICAgKiBoYXMgYSBtZXNzYWdlIGZvciB0aGVtLlxuICAgICpcbiAgICAqIEBwYXJhbSB7Kn0gZGF0YSAtIEFueSBqYXZhc2NyaXB0IG9iamVjdCB3aGljaCB3aWxsIGJlIGNyYWZ0ZWQgaW50byBhIE1lc3NhZ2VPYmplY3QuXG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ3NlbmQnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBzZW5kKGRhdGEpIHtcbiAgICAgIHZhciBvcHRpb25zID0gYXJndW1lbnRzLmxlbmd0aCA8PSAxIHx8IGFyZ3VtZW50c1sxXSA9PT0gdW5kZWZpbmVkID8ge30gOiBhcmd1bWVudHNbMV07XG5cbiAgICAgIHRoaXMuZW1pdCgnbWVzc2FnZScsIGRhdGEsIG9wdGlvbnMpO1xuICAgIH1cblxuICAgIC8qXG4gICAgKiBTZW5kcyBhIGdlbmVyaWMgbWVzc2FnZSBldmVudCB0byBhbGwgbW9jayBjbGllbnRzLlxuICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdlbWl0JyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gZW1pdChldmVudCwgZGF0YSkge1xuICAgICAgdmFyIF90aGlzMiA9IHRoaXM7XG5cbiAgICAgIHZhciBvcHRpb25zID0gYXJndW1lbnRzLmxlbmd0aCA8PSAyIHx8IGFyZ3VtZW50c1syXSA9PT0gdW5kZWZpbmVkID8ge30gOiBhcmd1bWVudHNbMl07XG4gICAgICB2YXIgd2Vic29ja2V0cyA9IG9wdGlvbnMud2Vic29ja2V0cztcblxuICAgICAgaWYgKCF3ZWJzb2NrZXRzKSB7XG4gICAgICAgIHdlYnNvY2tldHMgPSBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS53ZWJzb2NrZXRzTG9va3VwKHRoaXMudXJsKTtcbiAgICAgIH1cblxuICAgICAgd2Vic29ja2V0cy5mb3JFYWNoKGZ1bmN0aW9uIChzb2NrZXQpIHtcbiAgICAgICAgc29ja2V0LmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlTWVzc2FnZUV2ZW50KSh7XG4gICAgICAgICAgdHlwZTogZXZlbnQsXG4gICAgICAgICAgZGF0YTogZGF0YSxcbiAgICAgICAgICBvcmlnaW46IF90aGlzMi51cmwsXG4gICAgICAgICAgdGFyZ2V0OiBzb2NrZXRcbiAgICAgICAgfSkpO1xuICAgICAgfSk7XG4gICAgfVxuXG4gICAgLypcbiAgICAqIENsb3NlcyB0aGUgY29ubmVjdGlvbiBhbmQgdHJpZ2dlcnMgdGhlIG9uY2xvc2UgbWV0aG9kIG9mIGFsbCBsaXN0ZW5pbmdcbiAgICAqIHdlYnNvY2tldHMuIEFmdGVyIHRoYXQgaXQgcmVtb3ZlcyBpdHNlbGYgZnJvbSB0aGUgdXJsTWFwIHNvIGFub3RoZXIgc2VydmVyXG4gICAgKiBjb3VsZCBhZGQgaXRzZWxmIHRvIHRoZSB1cmwuXG4gICAgKlxuICAgICogQHBhcmFtIHtvYmplY3R9IG9wdGlvbnNcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAnY2xvc2UnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBjbG9zZSgpIHtcbiAgICAgIHZhciBvcHRpb25zID0gYXJndW1lbnRzLmxlbmd0aCA8PSAwIHx8IGFyZ3VtZW50c1swXSA9PT0gdW5kZWZpbmVkID8ge30gOiBhcmd1bWVudHNbMF07XG4gICAgICB2YXIgY29kZSA9IG9wdGlvbnMuY29kZTtcbiAgICAgIHZhciByZWFzb24gPSBvcHRpb25zLnJlYXNvbjtcbiAgICAgIHZhciB3YXNDbGVhbiA9IG9wdGlvbnMud2FzQ2xlYW47XG5cbiAgICAgIHZhciBsaXN0ZW5lcnMgPSBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS53ZWJzb2NrZXRzTG9va3VwKHRoaXMudXJsKTtcblxuICAgICAgbGlzdGVuZXJzLmZvckVhY2goZnVuY3Rpb24gKHNvY2tldCkge1xuICAgICAgICBzb2NrZXQucmVhZHlTdGF0ZSA9IF93ZWJzb2NrZXQyWydkZWZhdWx0J10uQ0xPU0U7XG4gICAgICAgIHNvY2tldC5kaXNwYXRjaEV2ZW50KCgwLCBfZXZlbnRGYWN0b3J5LmNyZWF0ZUNsb3NlRXZlbnQpKHtcbiAgICAgICAgICB0eXBlOiAnY2xvc2UnLFxuICAgICAgICAgIHRhcmdldDogc29ja2V0LFxuICAgICAgICAgIGNvZGU6IGNvZGUgfHwgX2hlbHBlcnNDbG9zZUNvZGVzMlsnZGVmYXVsdCddLkNMT1NFX05PUk1BTCxcbiAgICAgICAgICByZWFzb246IHJlYXNvbiB8fCAnJyxcbiAgICAgICAgICB3YXNDbGVhbjogd2FzQ2xlYW5cbiAgICAgICAgfSkpO1xuICAgICAgfSk7XG5cbiAgICAgIHRoaXMuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVDbG9zZUV2ZW50KSh7IHR5cGU6ICdjbG9zZScgfSksIHRoaXMpO1xuICAgICAgX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10ucmVtb3ZlU2VydmVyKHRoaXMudXJsKTtcbiAgICB9XG5cbiAgICAvKlxuICAgICogUmV0dXJucyBhbiBhcnJheSBvZiB3ZWJzb2NrZXRzIHdoaWNoIGFyZSBsaXN0ZW5pbmcgdG8gdGhpcyBzZXJ2ZXJcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAnY2xpZW50cycsXG4gICAgdmFsdWU6IGZ1bmN0aW9uIGNsaWVudHMoKSB7XG4gICAgICByZXR1cm4gX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10ud2Vic29ja2V0c0xvb2t1cCh0aGlzLnVybCk7XG4gICAgfVxuXG4gICAgLypcbiAgICAqIFByZXBhcmVzIGEgbWV0aG9kIHRvIHN1Ym1pdCBhbiBldmVudCB0byBtZW1iZXJzIG9mIHRoZSByb29tXG4gICAgKlxuICAgICogZS5nLiBzZXJ2ZXIudG8oJ215LXJvb20nKS5lbWl0KCdoaSEnKTtcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAndG8nLFxuICAgIHZhbHVlOiBmdW5jdGlvbiB0byhyb29tKSB7XG4gICAgICB2YXIgX3RoaXMgPSB0aGlzO1xuICAgICAgdmFyIHdlYnNvY2tldHMgPSBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS53ZWJzb2NrZXRzTG9va3VwKHRoaXMudXJsLCByb29tKTtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIGVtaXQ6IGZ1bmN0aW9uIGVtaXQoZXZlbnQsIGRhdGEpIHtcbiAgICAgICAgICBfdGhpcy5lbWl0KGV2ZW50LCBkYXRhLCB7IHdlYnNvY2tldHM6IHdlYnNvY2tldHMgfSk7XG4gICAgICAgIH1cbiAgICAgIH07XG4gICAgfVxuICB9XSk7XG5cbiAgcmV0dXJuIFNlcnZlcjtcbn0pKF9ldmVudFRhcmdldDJbJ2RlZmF1bHQnXSk7XG5cblNlcnZlci5vZiA9IGZ1bmN0aW9uIG9mKHVybCkge1xuICByZXR1cm4gbmV3IFNlcnZlcih1cmwpO1xufTtcblxuZXhwb3J0c1snZGVmYXVsdCddID0gU2VydmVyO1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzWydkZWZhdWx0J107IiwiJ3VzZSBzdHJpY3QnO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcblxudmFyIF9jcmVhdGVDbGFzcyA9IChmdW5jdGlvbiAoKSB7IGZ1bmN0aW9uIGRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBwcm9wcykgeyBmb3IgKHZhciBpID0gMDsgaSA8IHByb3BzLmxlbmd0aDsgaSsrKSB7IHZhciBkZXNjcmlwdG9yID0gcHJvcHNbaV07IGRlc2NyaXB0b3IuZW51bWVyYWJsZSA9IGRlc2NyaXB0b3IuZW51bWVyYWJsZSB8fCBmYWxzZTsgZGVzY3JpcHRvci5jb25maWd1cmFibGUgPSB0cnVlOyBpZiAoJ3ZhbHVlJyBpbiBkZXNjcmlwdG9yKSBkZXNjcmlwdG9yLndyaXRhYmxlID0gdHJ1ZTsgT2JqZWN0LmRlZmluZVByb3BlcnR5KHRhcmdldCwgZGVzY3JpcHRvci5rZXksIGRlc2NyaXB0b3IpOyB9IH0gcmV0dXJuIGZ1bmN0aW9uIChDb25zdHJ1Y3RvciwgcHJvdG9Qcm9wcywgc3RhdGljUHJvcHMpIHsgaWYgKHByb3RvUHJvcHMpIGRlZmluZVByb3BlcnRpZXMoQ29uc3RydWN0b3IucHJvdG90eXBlLCBwcm90b1Byb3BzKTsgaWYgKHN0YXRpY1Byb3BzKSBkZWZpbmVQcm9wZXJ0aWVzKENvbnN0cnVjdG9yLCBzdGF0aWNQcm9wcyk7IHJldHVybiBDb25zdHJ1Y3RvcjsgfTsgfSkoKTtcblxudmFyIF9nZXQgPSBmdW5jdGlvbiBnZXQoX3gzLCBfeDQsIF94NSkgeyB2YXIgX2FnYWluID0gdHJ1ZTsgX2Z1bmN0aW9uOiB3aGlsZSAoX2FnYWluKSB7IHZhciBvYmplY3QgPSBfeDMsIHByb3BlcnR5ID0gX3g0LCByZWNlaXZlciA9IF94NTsgX2FnYWluID0gZmFsc2U7IGlmIChvYmplY3QgPT09IG51bGwpIG9iamVjdCA9IEZ1bmN0aW9uLnByb3RvdHlwZTsgdmFyIGRlc2MgPSBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9yKG9iamVjdCwgcHJvcGVydHkpOyBpZiAoZGVzYyA9PT0gdW5kZWZpbmVkKSB7IHZhciBwYXJlbnQgPSBPYmplY3QuZ2V0UHJvdG90eXBlT2Yob2JqZWN0KTsgaWYgKHBhcmVudCA9PT0gbnVsbCkgeyByZXR1cm4gdW5kZWZpbmVkOyB9IGVsc2UgeyBfeDMgPSBwYXJlbnQ7IF94NCA9IHByb3BlcnR5OyBfeDUgPSByZWNlaXZlcjsgX2FnYWluID0gdHJ1ZTsgZGVzYyA9IHBhcmVudCA9IHVuZGVmaW5lZDsgY29udGludWUgX2Z1bmN0aW9uOyB9IH0gZWxzZSBpZiAoJ3ZhbHVlJyBpbiBkZXNjKSB7IHJldHVybiBkZXNjLnZhbHVlOyB9IGVsc2UgeyB2YXIgZ2V0dGVyID0gZGVzYy5nZXQ7IGlmIChnZXR0ZXIgPT09IHVuZGVmaW5lZCkgeyByZXR1cm4gdW5kZWZpbmVkOyB9IHJldHVybiBnZXR0ZXIuY2FsbChyZWNlaXZlcik7IH0gfSB9O1xuXG5mdW5jdGlvbiBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KG9iaikgeyByZXR1cm4gb2JqICYmIG9iai5fX2VzTW9kdWxlID8gb2JqIDogeyAnZGVmYXVsdCc6IG9iaiB9OyB9XG5cbmZ1bmN0aW9uIF9jbGFzc0NhbGxDaGVjayhpbnN0YW5jZSwgQ29uc3RydWN0b3IpIHsgaWYgKCEoaW5zdGFuY2UgaW5zdGFuY2VvZiBDb25zdHJ1Y3RvcikpIHsgdGhyb3cgbmV3IFR5cGVFcnJvcignQ2Fubm90IGNhbGwgYSBjbGFzcyBhcyBhIGZ1bmN0aW9uJyk7IH0gfVxuXG5mdW5jdGlvbiBfaW5oZXJpdHMoc3ViQ2xhc3MsIHN1cGVyQ2xhc3MpIHsgaWYgKHR5cGVvZiBzdXBlckNsYXNzICE9PSAnZnVuY3Rpb24nICYmIHN1cGVyQ2xhc3MgIT09IG51bGwpIHsgdGhyb3cgbmV3IFR5cGVFcnJvcignU3VwZXIgZXhwcmVzc2lvbiBtdXN0IGVpdGhlciBiZSBudWxsIG9yIGEgZnVuY3Rpb24sIG5vdCAnICsgdHlwZW9mIHN1cGVyQ2xhc3MpOyB9IHN1YkNsYXNzLnByb3RvdHlwZSA9IE9iamVjdC5jcmVhdGUoc3VwZXJDbGFzcyAmJiBzdXBlckNsYXNzLnByb3RvdHlwZSwgeyBjb25zdHJ1Y3RvcjogeyB2YWx1ZTogc3ViQ2xhc3MsIGVudW1lcmFibGU6IGZhbHNlLCB3cml0YWJsZTogdHJ1ZSwgY29uZmlndXJhYmxlOiB0cnVlIH0gfSk7IGlmIChzdXBlckNsYXNzKSBPYmplY3Quc2V0UHJvdG90eXBlT2YgPyBPYmplY3Quc2V0UHJvdG90eXBlT2Yoc3ViQ2xhc3MsIHN1cGVyQ2xhc3MpIDogc3ViQ2xhc3MuX19wcm90b19fID0gc3VwZXJDbGFzczsgfVxuXG52YXIgX3VyaWpzID0gcmVxdWlyZSgndXJpanMnKTtcblxudmFyIF91cmlqczIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF91cmlqcyk7XG5cbnZhciBfaGVscGVyc0RlbGF5ID0gcmVxdWlyZSgnLi9oZWxwZXJzL2RlbGF5Jyk7XG5cbnZhciBfaGVscGVyc0RlbGF5MiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2hlbHBlcnNEZWxheSk7XG5cbnZhciBfZXZlbnRUYXJnZXQgPSByZXF1aXJlKCcuL2V2ZW50LXRhcmdldCcpO1xuXG52YXIgX2V2ZW50VGFyZ2V0MiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2V2ZW50VGFyZ2V0KTtcblxudmFyIF9uZXR3b3JrQnJpZGdlID0gcmVxdWlyZSgnLi9uZXR3b3JrLWJyaWRnZScpO1xuXG52YXIgX25ldHdvcmtCcmlkZ2UyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfbmV0d29ya0JyaWRnZSk7XG5cbnZhciBfaGVscGVyc0Nsb3NlQ29kZXMgPSByZXF1aXJlKCcuL2hlbHBlcnMvY2xvc2UtY29kZXMnKTtcblxudmFyIF9oZWxwZXJzQ2xvc2VDb2RlczIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF9oZWxwZXJzQ2xvc2VDb2Rlcyk7XG5cbnZhciBfZXZlbnRGYWN0b3J5ID0gcmVxdWlyZSgnLi9ldmVudC1mYWN0b3J5Jyk7XG5cbi8qXG4qIFRoZSBzb2NrZXQtaW8gY2xhc3MgaXMgZGVzaWduZWQgdG8gbWltaWNrIHRoZSByZWFsIEFQSSBhcyBjbG9zZWx5IGFzIHBvc3NpYmxlLlxuKlxuKiBodHRwOi8vc29ja2V0LmlvL2RvY3MvXG4qL1xuXG52YXIgU29ja2V0SU8gPSAoZnVuY3Rpb24gKF9FdmVudFRhcmdldCkge1xuICBfaW5oZXJpdHMoU29ja2V0SU8sIF9FdmVudFRhcmdldCk7XG5cbiAgLypcbiAgKiBAcGFyYW0ge3N0cmluZ30gdXJsXG4gICovXG5cbiAgZnVuY3Rpb24gU29ja2V0SU8oKSB7XG4gICAgdmFyIF90aGlzID0gdGhpcztcblxuICAgIHZhciB1cmwgPSBhcmd1bWVudHMubGVuZ3RoIDw9IDAgfHwgYXJndW1lbnRzWzBdID09PSB1bmRlZmluZWQgPyAnc29ja2V0LmlvJyA6IGFyZ3VtZW50c1swXTtcbiAgICB2YXIgcHJvdG9jb2wgPSBhcmd1bWVudHMubGVuZ3RoIDw9IDEgfHwgYXJndW1lbnRzWzFdID09PSB1bmRlZmluZWQgPyAnJyA6IGFyZ3VtZW50c1sxXTtcblxuICAgIF9jbGFzc0NhbGxDaGVjayh0aGlzLCBTb2NrZXRJTyk7XG5cbiAgICBfZ2V0KE9iamVjdC5nZXRQcm90b3R5cGVPZihTb2NrZXRJTy5wcm90b3R5cGUpLCAnY29uc3RydWN0b3InLCB0aGlzKS5jYWxsKHRoaXMpO1xuXG4gICAgdGhpcy5iaW5hcnlUeXBlID0gJ2Jsb2InO1xuICAgIHRoaXMudXJsID0gKDAsIF91cmlqczJbJ2RlZmF1bHQnXSkodXJsKS50b1N0cmluZygpO1xuICAgIHRoaXMucmVhZHlTdGF0ZSA9IFNvY2tldElPLkNPTk5FQ1RJTkc7XG4gICAgdGhpcy5wcm90b2NvbCA9ICcnO1xuXG4gICAgaWYgKHR5cGVvZiBwcm90b2NvbCA9PT0gJ3N0cmluZycpIHtcbiAgICAgIHRoaXMucHJvdG9jb2wgPSBwcm90b2NvbDtcbiAgICB9IGVsc2UgaWYgKEFycmF5LmlzQXJyYXkocHJvdG9jb2wpICYmIHByb3RvY29sLmxlbmd0aCA+IDApIHtcbiAgICAgIHRoaXMucHJvdG9jb2wgPSBwcm90b2NvbFswXTtcbiAgICB9XG5cbiAgICB2YXIgc2VydmVyID0gX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10uYXR0YWNoV2ViU29ja2V0KHRoaXMsIHRoaXMudXJsKTtcblxuICAgIC8qXG4gICAgKiBEZWxheSB0cmlnZ2VyaW5nIHRoZSBjb25uZWN0aW9uIGV2ZW50cyBzbyB0aGV5IGNhbiBiZSBkZWZpbmVkIGluIHRpbWUuXG4gICAgKi9cbiAgICAoMCwgX2hlbHBlcnNEZWxheTJbJ2RlZmF1bHQnXSkoZnVuY3Rpb24gZGVsYXlDYWxsYmFjaygpIHtcbiAgICAgIGlmIChzZXJ2ZXIpIHtcbiAgICAgICAgdGhpcy5yZWFkeVN0YXRlID0gU29ja2V0SU8uT1BFTjtcbiAgICAgICAgc2VydmVyLmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlRXZlbnQpKHsgdHlwZTogJ2Nvbm5lY3Rpb24nIH0pLCBzZXJ2ZXIsIHRoaXMpO1xuICAgICAgICBzZXJ2ZXIuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVFdmVudCkoeyB0eXBlOiAnY29ubmVjdCcgfSksIHNlcnZlciwgdGhpcyk7IC8vIGFsaWFzXG4gICAgICAgIHRoaXMuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVFdmVudCkoeyB0eXBlOiAnY29ubmVjdCcsIHRhcmdldDogdGhpcyB9KSk7XG4gICAgICB9IGVsc2Uge1xuICAgICAgICB0aGlzLnJlYWR5U3RhdGUgPSBTb2NrZXRJTy5DTE9TRUQ7XG4gICAgICAgIHRoaXMuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVFdmVudCkoeyB0eXBlOiAnZXJyb3InLCB0YXJnZXQ6IHRoaXMgfSkpO1xuICAgICAgICB0aGlzLmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlQ2xvc2VFdmVudCkoe1xuICAgICAgICAgIHR5cGU6ICdjbG9zZScsXG4gICAgICAgICAgdGFyZ2V0OiB0aGlzLFxuICAgICAgICAgIGNvZGU6IF9oZWxwZXJzQ2xvc2VDb2RlczJbJ2RlZmF1bHQnXS5DTE9TRV9OT1JNQUxcbiAgICAgICAgfSkpO1xuXG4gICAgICAgIGNvbnNvbGUuZXJyb3IoJ1NvY2tldC5pbyBjb25uZWN0aW9uIHRvIFxcJycgKyB0aGlzLnVybCArICdcXCcgZmFpbGVkJyk7XG4gICAgICB9XG4gICAgfSwgdGhpcyk7XG5cbiAgICAvKipcbiAgICAgIEFkZCBhbiBhbGlhc2VkIGV2ZW50IGxpc3RlbmVyIGZvciBjbG9zZSAvIGRpc2Nvbm5lY3RcbiAgICAgKi9cbiAgICB0aGlzLmFkZEV2ZW50TGlzdGVuZXIoJ2Nsb3NlJywgZnVuY3Rpb24gKGV2ZW50KSB7XG4gICAgICBfdGhpcy5kaXNwYXRjaEV2ZW50KCgwLCBfZXZlbnRGYWN0b3J5LmNyZWF0ZUNsb3NlRXZlbnQpKHtcbiAgICAgICAgdHlwZTogJ2Rpc2Nvbm5lY3QnLFxuICAgICAgICB0YXJnZXQ6IGV2ZW50LnRhcmdldCxcbiAgICAgICAgY29kZTogZXZlbnQuY29kZVxuICAgICAgfSkpO1xuICAgIH0pO1xuICB9XG5cbiAgLypcbiAgKiBDbG9zZXMgdGhlIFNvY2tldElPIGNvbm5lY3Rpb24gb3IgY29ubmVjdGlvbiBhdHRlbXB0LCBpZiBhbnkuXG4gICogSWYgdGhlIGNvbm5lY3Rpb24gaXMgYWxyZWFkeSBDTE9TRUQsIHRoaXMgbWV0aG9kIGRvZXMgbm90aGluZy5cbiAgKi9cblxuICBfY3JlYXRlQ2xhc3MoU29ja2V0SU8sIFt7XG4gICAga2V5OiAnY2xvc2UnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBjbG9zZSgpIHtcbiAgICAgIGlmICh0aGlzLnJlYWR5U3RhdGUgIT09IFNvY2tldElPLk9QRU4pIHtcbiAgICAgICAgcmV0dXJuIHVuZGVmaW5lZDtcbiAgICAgIH1cblxuICAgICAgdmFyIHNlcnZlciA9IF9uZXR3b3JrQnJpZGdlMlsnZGVmYXVsdCddLnNlcnZlckxvb2t1cCh0aGlzLnVybCk7XG4gICAgICBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS5yZW1vdmVXZWJTb2NrZXQodGhpcywgdGhpcy51cmwpO1xuXG4gICAgICB0aGlzLnJlYWR5U3RhdGUgPSBTb2NrZXRJTy5DTE9TRUQ7XG4gICAgICB0aGlzLmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlQ2xvc2VFdmVudCkoe1xuICAgICAgICB0eXBlOiAnY2xvc2UnLFxuICAgICAgICB0YXJnZXQ6IHRoaXMsXG4gICAgICAgIGNvZGU6IF9oZWxwZXJzQ2xvc2VDb2RlczJbJ2RlZmF1bHQnXS5DTE9TRV9OT1JNQUxcbiAgICAgIH0pKTtcblxuICAgICAgaWYgKHNlcnZlcikge1xuICAgICAgICBzZXJ2ZXIuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVDbG9zZUV2ZW50KSh7XG4gICAgICAgICAgdHlwZTogJ2Rpc2Nvbm5lY3QnLFxuICAgICAgICAgIHRhcmdldDogdGhpcyxcbiAgICAgICAgICBjb2RlOiBfaGVscGVyc0Nsb3NlQ29kZXMyWydkZWZhdWx0J10uQ0xPU0VfTk9STUFMXG4gICAgICAgIH0pLCBzZXJ2ZXIpO1xuICAgICAgfVxuICAgIH1cblxuICAgIC8qXG4gICAgKiBBbGlhcyBmb3IgU29ja2V0I2Nsb3NlXG4gICAgKlxuICAgICogaHR0cHM6Ly9naXRodWIuY29tL3NvY2tldGlvL3NvY2tldC5pby1jbGllbnQvYmxvYi9tYXN0ZXIvbGliL3NvY2tldC5qcyNMMzgzXG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ2Rpc2Nvbm5lY3QnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBkaXNjb25uZWN0KCkge1xuICAgICAgdGhpcy5jbG9zZSgpO1xuICAgIH1cblxuICAgIC8qXG4gICAgKiBTdWJtaXRzIGFuIGV2ZW50IHRvIHRoZSBzZXJ2ZXIgd2l0aCBhIHBheWxvYWRcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAnZW1pdCcsXG4gICAgdmFsdWU6IGZ1bmN0aW9uIGVtaXQoZXZlbnQsIGRhdGEpIHtcbiAgICAgIGlmICh0aGlzLnJlYWR5U3RhdGUgIT09IFNvY2tldElPLk9QRU4pIHtcbiAgICAgICAgdGhyb3cgbmV3IEVycm9yKCdTb2NrZXRJTyBpcyBhbHJlYWR5IGluIENMT1NJTkcgb3IgQ0xPU0VEIHN0YXRlJyk7XG4gICAgICB9XG5cbiAgICAgIHZhciBtZXNzYWdlRXZlbnQgPSAoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVNZXNzYWdlRXZlbnQpKHtcbiAgICAgICAgdHlwZTogZXZlbnQsXG4gICAgICAgIG9yaWdpbjogdGhpcy51cmwsXG4gICAgICAgIGRhdGE6IGRhdGFcbiAgICAgIH0pO1xuXG4gICAgICB2YXIgc2VydmVyID0gX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10uc2VydmVyTG9va3VwKHRoaXMudXJsKTtcblxuICAgICAgaWYgKHNlcnZlcikge1xuICAgICAgICBzZXJ2ZXIuZGlzcGF0Y2hFdmVudChtZXNzYWdlRXZlbnQsIGRhdGEpO1xuICAgICAgfVxuICAgIH1cblxuICAgIC8qXG4gICAgKiBTdWJtaXRzIGEgJ21lc3NhZ2UnIGV2ZW50IHRvIHRoZSBzZXJ2ZXIuXG4gICAgKlxuICAgICogU2hvdWxkIGJlaGF2ZSBleGFjdGx5IGxpa2UgV2ViU29ja2V0I3NlbmRcbiAgICAqXG4gICAgKiBodHRwczovL2dpdGh1Yi5jb20vc29ja2V0aW8vc29ja2V0LmlvLWNsaWVudC9ibG9iL21hc3Rlci9saWIvc29ja2V0LmpzI0wxMTNcbiAgICAqL1xuICB9LCB7XG4gICAga2V5OiAnc2VuZCcsXG4gICAgdmFsdWU6IGZ1bmN0aW9uIHNlbmQoZGF0YSkge1xuICAgICAgdGhpcy5lbWl0KCdtZXNzYWdlJywgZGF0YSk7XG4gICAgfVxuXG4gICAgLypcbiAgICAqIEZvciByZWdpc3RlcmluZyBldmVudHMgdG8gYmUgcmVjZWl2ZWQgZnJvbSB0aGUgc2VydmVyXG4gICAgKi9cbiAgfSwge1xuICAgIGtleTogJ29uJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gb24odHlwZSwgY2FsbGJhY2spIHtcbiAgICAgIHRoaXMuYWRkRXZlbnRMaXN0ZW5lcih0eXBlLCBjYWxsYmFjayk7XG4gICAgfVxuXG4gICAgLypcbiAgICAgKiBKb2luIGEgcm9vbSBvbiBhIHNlcnZlclxuICAgICAqXG4gICAgICogaHR0cDovL3NvY2tldC5pby9kb2NzL3Jvb21zLWFuZC1uYW1lc3BhY2VzLyNqb2luaW5nLWFuZC1sZWF2aW5nXG4gICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdqb2luJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gam9pbihyb29tKSB7XG4gICAgICBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS5hZGRNZW1iZXJzaGlwVG9Sb29tKHRoaXMsIHJvb20pO1xuICAgIH1cblxuICAgIC8qXG4gICAgICogR2V0IHRoZSB3ZWJzb2NrZXQgdG8gbGVhdmUgdGhlIHJvb21cbiAgICAgKlxuICAgICAqIGh0dHA6Ly9zb2NrZXQuaW8vZG9jcy9yb29tcy1hbmQtbmFtZXNwYWNlcy8jam9pbmluZy1hbmQtbGVhdmluZ1xuICAgICAqL1xuICB9LCB7XG4gICAga2V5OiAnbGVhdmUnLFxuICAgIHZhbHVlOiBmdW5jdGlvbiBsZWF2ZShyb29tKSB7XG4gICAgICBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS5yZW1vdmVNZW1iZXJzaGlwRnJvbVJvb20odGhpcywgcm9vbSk7XG4gICAgfVxuXG4gICAgLypcbiAgICAgKiBJbnZva2VzIGFsbCBsaXN0ZW5lciBmdW5jdGlvbnMgdGhhdCBhcmUgbGlzdGVuaW5nIHRvIHRoZSBnaXZlbiBldmVudC50eXBlIHByb3BlcnR5LiBFYWNoXG4gICAgICogbGlzdGVuZXIgd2lsbCBiZSBwYXNzZWQgdGhlIGV2ZW50IGFzIHRoZSBmaXJzdCBhcmd1bWVudC5cbiAgICAgKlxuICAgICAqIEBwYXJhbSB7b2JqZWN0fSBldmVudCAtIGV2ZW50IG9iamVjdCB3aGljaCB3aWxsIGJlIHBhc3NlZCB0byBhbGwgbGlzdGVuZXJzIG9mIHRoZSBldmVudC50eXBlIHByb3BlcnR5XG4gICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdkaXNwYXRjaEV2ZW50JyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gZGlzcGF0Y2hFdmVudChldmVudCkge1xuICAgICAgdmFyIF90aGlzMiA9IHRoaXM7XG5cbiAgICAgIGZvciAodmFyIF9sZW4gPSBhcmd1bWVudHMubGVuZ3RoLCBjdXN0b21Bcmd1bWVudHMgPSBBcnJheShfbGVuID4gMSA/IF9sZW4gLSAxIDogMCksIF9rZXkgPSAxOyBfa2V5IDwgX2xlbjsgX2tleSsrKSB7XG4gICAgICAgIGN1c3RvbUFyZ3VtZW50c1tfa2V5IC0gMV0gPSBhcmd1bWVudHNbX2tleV07XG4gICAgICB9XG5cbiAgICAgIHZhciBldmVudE5hbWUgPSBldmVudC50eXBlO1xuICAgICAgdmFyIGxpc3RlbmVycyA9IHRoaXMubGlzdGVuZXJzW2V2ZW50TmFtZV07XG5cbiAgICAgIGlmICghQXJyYXkuaXNBcnJheShsaXN0ZW5lcnMpKSB7XG4gICAgICAgIHJldHVybiBmYWxzZTtcbiAgICAgIH1cblxuICAgICAgbGlzdGVuZXJzLmZvckVhY2goZnVuY3Rpb24gKGxpc3RlbmVyKSB7XG4gICAgICAgIGlmIChjdXN0b21Bcmd1bWVudHMubGVuZ3RoID4gMCkge1xuICAgICAgICAgIGxpc3RlbmVyLmFwcGx5KF90aGlzMiwgY3VzdG9tQXJndW1lbnRzKTtcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAvLyBSZWd1bGFyIFdlYlNvY2tldHMgZXhwZWN0IGEgTWVzc2FnZUV2ZW50IGJ1dCBTb2NrZXRpby5pbyBqdXN0IHdhbnRzIHJhdyBkYXRhXG4gICAgICAgICAgLy8gIHBheWxvYWQgaW5zdGFuY2VvZiBNZXNzYWdlRXZlbnQgd29ya3MsIGJ1dCB5b3UgY2FuJ3QgaXNudGFuY2Ugb2YgTm9kZUV2ZW50XG4gICAgICAgICAgLy8gIGZvciBub3cgd2UgZGV0ZWN0IGlmIHRoZSBvdXRwdXQgaGFzIGRhdGEgZGVmaW5lZCBvbiBpdFxuICAgICAgICAgIGxpc3RlbmVyLmNhbGwoX3RoaXMyLCBldmVudC5kYXRhID8gZXZlbnQuZGF0YSA6IGV2ZW50KTtcbiAgICAgICAgfVxuICAgICAgfSk7XG4gICAgfVxuICB9XSk7XG5cbiAgcmV0dXJuIFNvY2tldElPO1xufSkoX2V2ZW50VGFyZ2V0MlsnZGVmYXVsdCddKTtcblxuU29ja2V0SU8uQ09OTkVDVElORyA9IDA7XG5Tb2NrZXRJTy5PUEVOID0gMTtcblNvY2tldElPLkNMT1NJTkcgPSAyO1xuU29ja2V0SU8uQ0xPU0VEID0gMztcblxuLypcbiogU3RhdGljIGNvbnN0cnVjdG9yIG1ldGhvZHMgZm9yIHRoZSBJTyBTb2NrZXRcbiovXG52YXIgSU8gPSBmdW5jdGlvbiBpb0NvbnN0cnVjdG9yKHVybCkge1xuICByZXR1cm4gbmV3IFNvY2tldElPKHVybCk7XG59O1xuXG4vKlxuKiBBbGlhcyB0aGUgcmF3IElPKCkgY29uc3RydWN0b3JcbiovXG5JTy5jb25uZWN0ID0gZnVuY3Rpb24gaW9Db25uZWN0KHVybCkge1xuICAvKiBlc2xpbnQtZGlzYWJsZSBuZXctY2FwICovXG4gIHJldHVybiBJTyh1cmwpO1xuICAvKiBlc2xpbnQtZW5hYmxlIG5ldy1jYXAgKi9cbn07XG5cbmV4cG9ydHNbJ2RlZmF1bHQnXSA9IElPO1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzWydkZWZhdWx0J107IiwiJ3VzZSBzdHJpY3QnO1xuXG5PYmplY3QuZGVmaW5lUHJvcGVydHkoZXhwb3J0cywgJ19fZXNNb2R1bGUnLCB7XG4gIHZhbHVlOiB0cnVlXG59KTtcblxudmFyIF9jcmVhdGVDbGFzcyA9IChmdW5jdGlvbiAoKSB7IGZ1bmN0aW9uIGRlZmluZVByb3BlcnRpZXModGFyZ2V0LCBwcm9wcykgeyBmb3IgKHZhciBpID0gMDsgaSA8IHByb3BzLmxlbmd0aDsgaSsrKSB7IHZhciBkZXNjcmlwdG9yID0gcHJvcHNbaV07IGRlc2NyaXB0b3IuZW51bWVyYWJsZSA9IGRlc2NyaXB0b3IuZW51bWVyYWJsZSB8fCBmYWxzZTsgZGVzY3JpcHRvci5jb25maWd1cmFibGUgPSB0cnVlOyBpZiAoJ3ZhbHVlJyBpbiBkZXNjcmlwdG9yKSBkZXNjcmlwdG9yLndyaXRhYmxlID0gdHJ1ZTsgT2JqZWN0LmRlZmluZVByb3BlcnR5KHRhcmdldCwgZGVzY3JpcHRvci5rZXksIGRlc2NyaXB0b3IpOyB9IH0gcmV0dXJuIGZ1bmN0aW9uIChDb25zdHJ1Y3RvciwgcHJvdG9Qcm9wcywgc3RhdGljUHJvcHMpIHsgaWYgKHByb3RvUHJvcHMpIGRlZmluZVByb3BlcnRpZXMoQ29uc3RydWN0b3IucHJvdG90eXBlLCBwcm90b1Byb3BzKTsgaWYgKHN0YXRpY1Byb3BzKSBkZWZpbmVQcm9wZXJ0aWVzKENvbnN0cnVjdG9yLCBzdGF0aWNQcm9wcyk7IHJldHVybiBDb25zdHJ1Y3RvcjsgfTsgfSkoKTtcblxudmFyIF9nZXQgPSBmdW5jdGlvbiBnZXQoX3gyLCBfeDMsIF94NCkgeyB2YXIgX2FnYWluID0gdHJ1ZTsgX2Z1bmN0aW9uOiB3aGlsZSAoX2FnYWluKSB7IHZhciBvYmplY3QgPSBfeDIsIHByb3BlcnR5ID0gX3gzLCByZWNlaXZlciA9IF94NDsgX2FnYWluID0gZmFsc2U7IGlmIChvYmplY3QgPT09IG51bGwpIG9iamVjdCA9IEZ1bmN0aW9uLnByb3RvdHlwZTsgdmFyIGRlc2MgPSBPYmplY3QuZ2V0T3duUHJvcGVydHlEZXNjcmlwdG9yKG9iamVjdCwgcHJvcGVydHkpOyBpZiAoZGVzYyA9PT0gdW5kZWZpbmVkKSB7IHZhciBwYXJlbnQgPSBPYmplY3QuZ2V0UHJvdG90eXBlT2Yob2JqZWN0KTsgaWYgKHBhcmVudCA9PT0gbnVsbCkgeyByZXR1cm4gdW5kZWZpbmVkOyB9IGVsc2UgeyBfeDIgPSBwYXJlbnQ7IF94MyA9IHByb3BlcnR5OyBfeDQgPSByZWNlaXZlcjsgX2FnYWluID0gdHJ1ZTsgZGVzYyA9IHBhcmVudCA9IHVuZGVmaW5lZDsgY29udGludWUgX2Z1bmN0aW9uOyB9IH0gZWxzZSBpZiAoJ3ZhbHVlJyBpbiBkZXNjKSB7IHJldHVybiBkZXNjLnZhbHVlOyB9IGVsc2UgeyB2YXIgZ2V0dGVyID0gZGVzYy5nZXQ7IGlmIChnZXR0ZXIgPT09IHVuZGVmaW5lZCkgeyByZXR1cm4gdW5kZWZpbmVkOyB9IHJldHVybiBnZXR0ZXIuY2FsbChyZWNlaXZlcik7IH0gfSB9O1xuXG5mdW5jdGlvbiBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KG9iaikgeyByZXR1cm4gb2JqICYmIG9iai5fX2VzTW9kdWxlID8gb2JqIDogeyAnZGVmYXVsdCc6IG9iaiB9OyB9XG5cbmZ1bmN0aW9uIF9jbGFzc0NhbGxDaGVjayhpbnN0YW5jZSwgQ29uc3RydWN0b3IpIHsgaWYgKCEoaW5zdGFuY2UgaW5zdGFuY2VvZiBDb25zdHJ1Y3RvcikpIHsgdGhyb3cgbmV3IFR5cGVFcnJvcignQ2Fubm90IGNhbGwgYSBjbGFzcyBhcyBhIGZ1bmN0aW9uJyk7IH0gfVxuXG5mdW5jdGlvbiBfaW5oZXJpdHMoc3ViQ2xhc3MsIHN1cGVyQ2xhc3MpIHsgaWYgKHR5cGVvZiBzdXBlckNsYXNzICE9PSAnZnVuY3Rpb24nICYmIHN1cGVyQ2xhc3MgIT09IG51bGwpIHsgdGhyb3cgbmV3IFR5cGVFcnJvcignU3VwZXIgZXhwcmVzc2lvbiBtdXN0IGVpdGhlciBiZSBudWxsIG9yIGEgZnVuY3Rpb24sIG5vdCAnICsgdHlwZW9mIHN1cGVyQ2xhc3MpOyB9IHN1YkNsYXNzLnByb3RvdHlwZSA9IE9iamVjdC5jcmVhdGUoc3VwZXJDbGFzcyAmJiBzdXBlckNsYXNzLnByb3RvdHlwZSwgeyBjb25zdHJ1Y3RvcjogeyB2YWx1ZTogc3ViQ2xhc3MsIGVudW1lcmFibGU6IGZhbHNlLCB3cml0YWJsZTogdHJ1ZSwgY29uZmlndXJhYmxlOiB0cnVlIH0gfSk7IGlmIChzdXBlckNsYXNzKSBPYmplY3Quc2V0UHJvdG90eXBlT2YgPyBPYmplY3Quc2V0UHJvdG90eXBlT2Yoc3ViQ2xhc3MsIHN1cGVyQ2xhc3MpIDogc3ViQ2xhc3MuX19wcm90b19fID0gc3VwZXJDbGFzczsgfVxuXG52YXIgX3VyaWpzID0gcmVxdWlyZSgndXJpanMnKTtcblxudmFyIF91cmlqczIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF91cmlqcyk7XG5cbnZhciBfaGVscGVyc0RlbGF5ID0gcmVxdWlyZSgnLi9oZWxwZXJzL2RlbGF5Jyk7XG5cbnZhciBfaGVscGVyc0RlbGF5MiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2hlbHBlcnNEZWxheSk7XG5cbnZhciBfZXZlbnRUYXJnZXQgPSByZXF1aXJlKCcuL2V2ZW50LXRhcmdldCcpO1xuXG52YXIgX2V2ZW50VGFyZ2V0MiA9IF9pbnRlcm9wUmVxdWlyZURlZmF1bHQoX2V2ZW50VGFyZ2V0KTtcblxudmFyIF9uZXR3b3JrQnJpZGdlID0gcmVxdWlyZSgnLi9uZXR3b3JrLWJyaWRnZScpO1xuXG52YXIgX25ldHdvcmtCcmlkZ2UyID0gX2ludGVyb3BSZXF1aXJlRGVmYXVsdChfbmV0d29ya0JyaWRnZSk7XG5cbnZhciBfaGVscGVyc0Nsb3NlQ29kZXMgPSByZXF1aXJlKCcuL2hlbHBlcnMvY2xvc2UtY29kZXMnKTtcblxudmFyIF9oZWxwZXJzQ2xvc2VDb2RlczIgPSBfaW50ZXJvcFJlcXVpcmVEZWZhdWx0KF9oZWxwZXJzQ2xvc2VDb2Rlcyk7XG5cbnZhciBfZXZlbnRGYWN0b3J5ID0gcmVxdWlyZSgnLi9ldmVudC1mYWN0b3J5Jyk7XG5cbi8qXG4qIFRoZSBtYWluIHdlYnNvY2tldCBjbGFzcyB3aGljaCBpcyBkZXNpZ25lZCB0byBtaW1pY2sgdGhlIG5hdGl2ZSBXZWJTb2NrZXQgY2xhc3MgYXMgY2xvc2VcbiogYXMgcG9zc2libGUuXG4qXG4qIGh0dHBzOi8vZGV2ZWxvcGVyLm1vemlsbGEub3JnL2VuLVVTL2RvY3MvV2ViL0FQSS9XZWJTb2NrZXRcbiovXG5cbnZhciBXZWJTb2NrZXQgPSAoZnVuY3Rpb24gKF9FdmVudFRhcmdldCkge1xuICBfaW5oZXJpdHMoV2ViU29ja2V0LCBfRXZlbnRUYXJnZXQpO1xuXG4gIC8qXG4gICogQHBhcmFtIHtzdHJpbmd9IHVybFxuICAqL1xuXG4gIGZ1bmN0aW9uIFdlYlNvY2tldCh1cmwpIHtcbiAgICB2YXIgcHJvdG9jb2wgPSBhcmd1bWVudHMubGVuZ3RoIDw9IDEgfHwgYXJndW1lbnRzWzFdID09PSB1bmRlZmluZWQgPyAnJyA6IGFyZ3VtZW50c1sxXTtcblxuICAgIF9jbGFzc0NhbGxDaGVjayh0aGlzLCBXZWJTb2NrZXQpO1xuXG4gICAgX2dldChPYmplY3QuZ2V0UHJvdG90eXBlT2YoV2ViU29ja2V0LnByb3RvdHlwZSksICdjb25zdHJ1Y3RvcicsIHRoaXMpLmNhbGwodGhpcyk7XG5cbiAgICBpZiAoIXVybCkge1xuICAgICAgdGhyb3cgbmV3IFR5cGVFcnJvcignRmFpbGVkIHRvIGNvbnN0cnVjdCBcXCdXZWJTb2NrZXRcXCc6IDEgYXJndW1lbnQgcmVxdWlyZWQsIGJ1dCBvbmx5IDAgcHJlc2VudC4nKTtcbiAgICB9XG5cbiAgICB0aGlzLmJpbmFyeVR5cGUgPSAnYmxvYic7XG4gICAgdGhpcy51cmwgPSAoMCwgX3VyaWpzMlsnZGVmYXVsdCddKSh1cmwpLnRvU3RyaW5nKCk7XG4gICAgdGhpcy5yZWFkeVN0YXRlID0gV2ViU29ja2V0LkNPTk5FQ1RJTkc7XG4gICAgdGhpcy5wcm90b2NvbCA9ICcnO1xuXG4gICAgaWYgKHR5cGVvZiBwcm90b2NvbCA9PT0gJ3N0cmluZycpIHtcbiAgICAgIHRoaXMucHJvdG9jb2wgPSBwcm90b2NvbDtcbiAgICB9IGVsc2UgaWYgKEFycmF5LmlzQXJyYXkocHJvdG9jb2wpICYmIHByb3RvY29sLmxlbmd0aCA+IDApIHtcbiAgICAgIHRoaXMucHJvdG9jb2wgPSBwcm90b2NvbFswXTtcbiAgICB9XG5cbiAgICAvKlxuICAgICogSW4gb3JkZXIgdG8gY2FwdHVyZSB0aGUgY2FsbGJhY2sgZnVuY3Rpb24gd2UgbmVlZCB0byBkZWZpbmUgY3VzdG9tIHNldHRlcnMuXG4gICAgKiBUbyBpbGx1c3RyYXRlOlxuICAgICogICBteVNvY2tldC5vbm9wZW4gPSBmdW5jdGlvbigpIHsgYWxlcnQodHJ1ZSkgfTtcbiAgICAqXG4gICAgKiBUaGUgb25seSB3YXkgdG8gY2FwdHVyZSB0aGF0IGZ1bmN0aW9uIGFuZCBob2xkIG9udG8gaXQgZm9yIGxhdGVyIGlzIHdpdGggdGhlXG4gICAgKiBiZWxvdyBjb2RlOlxuICAgICovXG4gICAgT2JqZWN0LmRlZmluZVByb3BlcnRpZXModGhpcywge1xuICAgICAgb25vcGVuOiB7XG4gICAgICAgIGNvbmZpZ3VyYWJsZTogdHJ1ZSxcbiAgICAgICAgZW51bWVyYWJsZTogdHJ1ZSxcbiAgICAgICAgZ2V0OiBmdW5jdGlvbiBnZXQoKSB7XG4gICAgICAgICAgcmV0dXJuIHRoaXMubGlzdGVuZXJzLm9wZW47XG4gICAgICAgIH0sXG4gICAgICAgIHNldDogZnVuY3Rpb24gc2V0KGxpc3RlbmVyKSB7XG4gICAgICAgICAgdGhpcy5hZGRFdmVudExpc3RlbmVyKCdvcGVuJywgbGlzdGVuZXIpO1xuICAgICAgICB9XG4gICAgICB9LFxuICAgICAgb25tZXNzYWdlOiB7XG4gICAgICAgIGNvbmZpZ3VyYWJsZTogdHJ1ZSxcbiAgICAgICAgZW51bWVyYWJsZTogdHJ1ZSxcbiAgICAgICAgZ2V0OiBmdW5jdGlvbiBnZXQoKSB7XG4gICAgICAgICAgcmV0dXJuIHRoaXMubGlzdGVuZXJzLm1lc3NhZ2U7XG4gICAgICAgIH0sXG4gICAgICAgIHNldDogZnVuY3Rpb24gc2V0KGxpc3RlbmVyKSB7XG4gICAgICAgICAgdGhpcy5hZGRFdmVudExpc3RlbmVyKCdtZXNzYWdlJywgbGlzdGVuZXIpO1xuICAgICAgICB9XG4gICAgICB9LFxuICAgICAgb25jbG9zZToge1xuICAgICAgICBjb25maWd1cmFibGU6IHRydWUsXG4gICAgICAgIGVudW1lcmFibGU6IHRydWUsXG4gICAgICAgIGdldDogZnVuY3Rpb24gZ2V0KCkge1xuICAgICAgICAgIHJldHVybiB0aGlzLmxpc3RlbmVycy5jbG9zZTtcbiAgICAgICAgfSxcbiAgICAgICAgc2V0OiBmdW5jdGlvbiBzZXQobGlzdGVuZXIpIHtcbiAgICAgICAgICB0aGlzLmFkZEV2ZW50TGlzdGVuZXIoJ2Nsb3NlJywgbGlzdGVuZXIpO1xuICAgICAgICB9XG4gICAgICB9LFxuICAgICAgb25lcnJvcjoge1xuICAgICAgICBjb25maWd1cmFibGU6IHRydWUsXG4gICAgICAgIGVudW1lcmFibGU6IHRydWUsXG4gICAgICAgIGdldDogZnVuY3Rpb24gZ2V0KCkge1xuICAgICAgICAgIHJldHVybiB0aGlzLmxpc3RlbmVycy5lcnJvcjtcbiAgICAgICAgfSxcbiAgICAgICAgc2V0OiBmdW5jdGlvbiBzZXQobGlzdGVuZXIpIHtcbiAgICAgICAgICB0aGlzLmFkZEV2ZW50TGlzdGVuZXIoJ2Vycm9yJywgbGlzdGVuZXIpO1xuICAgICAgICB9XG4gICAgICB9XG4gICAgfSk7XG5cbiAgICB2YXIgc2VydmVyID0gX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10uYXR0YWNoV2ViU29ja2V0KHRoaXMsIHRoaXMudXJsKTtcblxuICAgIC8qXG4gICAgKiBUaGlzIGRlbGF5IGlzIG5lZWRlZCBzbyB0aGF0IHdlIGRvbnQgdHJpZ2dlciBhbiBldmVudCBiZWZvcmUgdGhlIGNhbGxiYWNrcyBoYXZlIGJlZW5cbiAgICAqIHNldHVwLiBGb3IgZXhhbXBsZTpcbiAgICAqXG4gICAgKiB2YXIgc29ja2V0ID0gbmV3IFdlYlNvY2tldCgnd3M6Ly9sb2NhbGhvc3QnKTtcbiAgICAqXG4gICAgKiAvLyBJZiB3ZSBkb250IGhhdmUgdGhlIGRlbGF5IHRoZW4gdGhlIGV2ZW50IHdvdWxkIGJlIHRyaWdnZXJlZCByaWdodCBoZXJlIGFuZCB0aGlzIGlzXG4gICAgKiAvLyBiZWZvcmUgdGhlIG9ub3BlbiBoYWQgYSBjaGFuY2UgdG8gcmVnaXN0ZXIgaXRzZWxmLlxuICAgICpcbiAgICAqIHNvY2tldC5vbm9wZW4gPSAoKSA9PiB7IC8vIHRoaXMgd291bGQgbmV2ZXIgYmUgY2FsbGVkIH07XG4gICAgKlxuICAgICogLy8gYW5kIHdpdGggdGhlIGRlbGF5IHRoZSBldmVudCBnZXRzIHRyaWdnZXJlZCBoZXJlIGFmdGVyIGFsbCBvZiB0aGUgY2FsbGJhY2tzIGhhdmUgYmVlblxuICAgICogLy8gcmVnaXN0ZXJlZCA6LSlcbiAgICAqL1xuICAgICgwLCBfaGVscGVyc0RlbGF5MlsnZGVmYXVsdCddKShmdW5jdGlvbiBkZWxheUNhbGxiYWNrKCkge1xuICAgICAgaWYgKHNlcnZlcikge1xuICAgICAgICB0aGlzLnJlYWR5U3RhdGUgPSBXZWJTb2NrZXQuT1BFTjtcbiAgICAgICAgc2VydmVyLmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlRXZlbnQpKHsgdHlwZTogJ2Nvbm5lY3Rpb24nIH0pLCBzZXJ2ZXIsIHRoaXMpO1xuICAgICAgICB0aGlzLmRpc3BhdGNoRXZlbnQoKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlRXZlbnQpKHsgdHlwZTogJ29wZW4nLCB0YXJnZXQ6IHRoaXMgfSkpO1xuICAgICAgfSBlbHNlIHtcbiAgICAgICAgdGhpcy5yZWFkeVN0YXRlID0gV2ViU29ja2V0LkNMT1NFRDtcbiAgICAgICAgdGhpcy5kaXNwYXRjaEV2ZW50KCgwLCBfZXZlbnRGYWN0b3J5LmNyZWF0ZUV2ZW50KSh7IHR5cGU6ICdlcnJvcicsIHRhcmdldDogdGhpcyB9KSk7XG4gICAgICAgIHRoaXMuZGlzcGF0Y2hFdmVudCgoMCwgX2V2ZW50RmFjdG9yeS5jcmVhdGVDbG9zZUV2ZW50KSh7IHR5cGU6ICdjbG9zZScsIHRhcmdldDogdGhpcywgY29kZTogX2hlbHBlcnNDbG9zZUNvZGVzMlsnZGVmYXVsdCddLkNMT1NFX05PUk1BTCB9KSk7XG5cbiAgICAgICAgY29uc29sZS5lcnJvcignV2ViU29ja2V0IGNvbm5lY3Rpb24gdG8gXFwnJyArIHRoaXMudXJsICsgJ1xcJyBmYWlsZWQnKTtcbiAgICAgIH1cbiAgICB9LCB0aGlzKTtcbiAgfVxuXG4gIC8qXG4gICogVHJhbnNtaXRzIGRhdGEgdG8gdGhlIHNlcnZlciBvdmVyIHRoZSBXZWJTb2NrZXQgY29ubmVjdGlvbi5cbiAgKlxuICAqIGh0dHBzOi8vZGV2ZWxvcGVyLm1vemlsbGEub3JnL2VuLVVTL2RvY3MvV2ViL0FQSS9XZWJTb2NrZXQjc2VuZCgpXG4gICovXG5cbiAgX2NyZWF0ZUNsYXNzKFdlYlNvY2tldCwgW3tcbiAgICBrZXk6ICdzZW5kJyxcbiAgICB2YWx1ZTogZnVuY3Rpb24gc2VuZChkYXRhKSB7XG4gICAgICBpZiAodGhpcy5yZWFkeVN0YXRlID09PSBXZWJTb2NrZXQuQ0xPU0lORyB8fCB0aGlzLnJlYWR5U3RhdGUgPT09IFdlYlNvY2tldC5DTE9TRUQpIHtcbiAgICAgICAgdGhyb3cgbmV3IEVycm9yKCdXZWJTb2NrZXQgaXMgYWxyZWFkeSBpbiBDTE9TSU5HIG9yIENMT1NFRCBzdGF0ZScpO1xuICAgICAgfVxuXG4gICAgICB2YXIgbWVzc2FnZUV2ZW50ID0gKDAsIF9ldmVudEZhY3RvcnkuY3JlYXRlTWVzc2FnZUV2ZW50KSh7XG4gICAgICAgIHR5cGU6ICdtZXNzYWdlJyxcbiAgICAgICAgb3JpZ2luOiB0aGlzLnVybCxcbiAgICAgICAgZGF0YTogZGF0YVxuICAgICAgfSk7XG5cbiAgICAgIHZhciBzZXJ2ZXIgPSBfbmV0d29ya0JyaWRnZTJbJ2RlZmF1bHQnXS5zZXJ2ZXJMb29rdXAodGhpcy51cmwpO1xuXG4gICAgICBpZiAoc2VydmVyKSB7XG4gICAgICAgIHNlcnZlci5kaXNwYXRjaEV2ZW50KG1lc3NhZ2VFdmVudCwgZGF0YSk7XG4gICAgICB9XG4gICAgfVxuXG4gICAgLypcbiAgICAqIENsb3NlcyB0aGUgV2ViU29ja2V0IGNvbm5lY3Rpb24gb3IgY29ubmVjdGlvbiBhdHRlbXB0LCBpZiBhbnkuXG4gICAgKiBJZiB0aGUgY29ubmVjdGlvbiBpcyBhbHJlYWR5IENMT1NFRCwgdGhpcyBtZXRob2QgZG9lcyBub3RoaW5nLlxuICAgICpcbiAgICAqIGh0dHBzOi8vZGV2ZWxvcGVyLm1vemlsbGEub3JnL2VuLVVTL2RvY3MvV2ViL0FQSS9XZWJTb2NrZXQjY2xvc2UoKVxuICAgICovXG4gIH0sIHtcbiAgICBrZXk6ICdjbG9zZScsXG4gICAgdmFsdWU6IGZ1bmN0aW9uIGNsb3NlKCkge1xuICAgICAgaWYgKHRoaXMucmVhZHlTdGF0ZSAhPT0gV2ViU29ja2V0Lk9QRU4pIHtcbiAgICAgICAgcmV0dXJuIHVuZGVmaW5lZDtcbiAgICAgIH1cblxuICAgICAgdmFyIHNlcnZlciA9IF9uZXR3b3JrQnJpZGdlMlsnZGVmYXVsdCddLnNlcnZlckxvb2t1cCh0aGlzLnVybCk7XG4gICAgICB2YXIgY2xvc2VFdmVudCA9ICgwLCBfZXZlbnRGYWN0b3J5LmNyZWF0ZUNsb3NlRXZlbnQpKHtcbiAgICAgICAgdHlwZTogJ2Nsb3NlJyxcbiAgICAgICAgdGFyZ2V0OiB0aGlzLFxuICAgICAgICBjb2RlOiBfaGVscGVyc0Nsb3NlQ29kZXMyWydkZWZhdWx0J10uQ0xPU0VfTk9STUFMXG4gICAgICB9KTtcblxuICAgICAgX25ldHdvcmtCcmlkZ2UyWydkZWZhdWx0J10ucmVtb3ZlV2ViU29ja2V0KHRoaXMsIHRoaXMudXJsKTtcblxuICAgICAgdGhpcy5yZWFkeVN0YXRlID0gV2ViU29ja2V0LkNMT1NFRDtcbiAgICAgIHRoaXMuZGlzcGF0Y2hFdmVudChjbG9zZUV2ZW50KTtcblxuICAgICAgaWYgKHNlcnZlcikge1xuICAgICAgICBzZXJ2ZXIuZGlzcGF0Y2hFdmVudChjbG9zZUV2ZW50LCBzZXJ2ZXIpO1xuICAgICAgfVxuICAgIH1cbiAgfV0pO1xuXG4gIHJldHVybiBXZWJTb2NrZXQ7XG59KShfZXZlbnRUYXJnZXQyWydkZWZhdWx0J10pO1xuXG5XZWJTb2NrZXQuQ09OTkVDVElORyA9IDA7XG5XZWJTb2NrZXQuT1BFTiA9IDE7XG5XZWJTb2NrZXQuQ0xPU0lORyA9IDI7XG5XZWJTb2NrZXQuQ0xPU0VEID0gMztcblxuZXhwb3J0c1snZGVmYXVsdCddID0gV2ViU29ja2V0O1xubW9kdWxlLmV4cG9ydHMgPSBleHBvcnRzWydkZWZhdWx0J107Il19
