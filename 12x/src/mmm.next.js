// ==UserScript==
// @name         MegaMegaMonitor
// @namespace    https://danq.me/megamegamonitor/
// @version      99.beta
// @description  Spot your MegaFriends around the rest of Reddit.
// @author       Dan Q (/u/avapoet)
// @downloadURL  https://danq.me/megamegamonitor/MegaMegaMonitor.next.user.js
// @require      https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js
// @include      *.reddit.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// ==/UserScript==
var dataAge, debugMode, lastUpdated, lastVersion, modifyPage, updateUserData, userData,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

debugMode = true;

this.$ = this.jQuery = jQuery.noConflict(true);

/**
 * Returns a description of this date in relative terms.

 * Examples, where new Date().toString() == "Mon Nov 23 2009 17:36:51 GMT-0500 (EST)":
 *
 * new Date().toRelativeTime()
 * --> 'Just now'
 *
 * new Date("Nov 21, 2009").toRelativeTime()
 * --> '2 days ago'
 *
 * new Date("Nov 25, 2009").toRelativeTime()
 * --> '2 days from now'
 *
 * // One second ago
 * new Date("Nov 23 2009 17:36:50 GMT-0500 (EST)").toRelativeTime()
 * --> '1 second ago'
 *
 * toRelativeTime() takes an optional argument - a configuration object.
 * It can have the following properties:
 * - now - Date object that defines "now" for the purpose of conversion.
 *         By default, current date & time is used (i.e. new Date())
 * - nowThreshold - Threshold in milliseconds which is considered "Just now"
 *                  for times in the past or "Right now" for now or the immediate future
 * - smartDays - If enabled, dates within a week of now will use Today/Yesterday/Tomorrow
 *               or weekdays along with time, e.g. "Thursday at 15:10:34"
 *               rather than "4 days ago" or "Tomorrow at 20:12:01"
 *               instead of "1 day from now"
 * - texts - If provided it will be the source of all texts used for creation
 *           of time difference text, it should also provide pluralization function
 *           which will be feed up with time units 
 *               
 * If a single number is given as argument, it is interpreted as nowThreshold:
 *
 * // One second ago, now setting a now_threshold to 5 seconds
 * new Date("Nov 23 2009 17:36:50 GMT-0500 (EST)").toRelativeTime(5000)
 * --> 'Just now'
 *
 * // One second in the future, now setting a now_threshold to 5 seconds
 * new Date("Nov 23 2009 17:36:52 GMT-0500 (EST)").toRelativeTime(5000)
 * --> 'Right now'
 *
 */
 Date.prototype.toRelativeTime = (function() {

  var _ = function(options) {
    var opts = processOptions(options);

    var now = opts.now || new Date();
    var texts = opts.texts || TEXTS;
    var delta = now - this;
    var future = (delta <= 0);
    delta = Math.abs(delta);

    // special cases controlled by options
    if (delta <= opts.nowThreshold) {
      return future ? texts.right_now : texts.just_now;
    }
    if (opts.smartDays && delta <= 6 * MS_IN_DAY) {
      return toSmartDays(this, now, texts);
    }

    var units = null;
    for (var key in CONVERSIONS) {
      if (delta < CONVERSIONS[key])
        break;
      units = key; // keeps track of the selected key over the iteration
      delta = delta / CONVERSIONS[key];
    }

    // pluralize a unit when the difference is greater than 1.
    delta = Math.floor(delta);
    units = texts.pluralize(delta, units);
    return [delta, units, future ? texts.from_now : texts.ago].join(" ");
  };

  var processOptions = function(arg) {
    if (!arg) arg = 0;
    if (typeof arg === 'string') {
      arg = parseInt(arg, 10);
    }
    if (typeof arg === 'number') {
      if (isNaN(arg)) arg = 0;
      return {nowThreshold: arg};
    }
    return arg;
  };

  var toSmartDays = function(date, now, texts) {
    var day;
    var weekday = date.getDay(),
        dayDiff = weekday - now.getDay();
    if (dayDiff == 0)       day = texts.today;
    else if (dayDiff == -1) day = texts.yesterday;
    else if (dayDiff == 1 && date > now)  
                            day = texts.tomorrow;
    else                    day = texts.days[weekday];
    return day + " " + texts.at + " " + date.toLocaleTimeString();
  };

  var CONVERSIONS = {
    millisecond: 1, // ms    -> ms
    second: 1000,   // ms    -> sec
    minute: 60,     // sec   -> min
    hour:   60,     // min   -> hour
    day:    24,     // hour  -> day
    month:  30,     // day   -> month (roughly)
    year:   12      // month -> year
  };
  
  var MS_IN_DAY = (CONVERSIONS.millisecond * CONVERSIONS.second * CONVERSIONS.minute * CONVERSIONS.hour * CONVERSIONS.day);

  var WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  var TEXTS = {today:        'Today', 
               yesterday:    'Yesterday', 
               tomorrow:     'Tomorrow',
               at:           'at',
               from_now:     'from now',
               ago:          'ago',
               right_now:    'Right now',
               just_now:     'Just now',
               days:         WEEKDAYS,
               pluralize:    function(val, text) {
                                if(val > 1)
                                    return text + "s";
                                return text;
                             }
               };
  return _;
})();



/*
 * Wraps up a common pattern used with this plugin whereby you take a String
 * representation of a Date, and want back a date object.
 */
Date.fromString = function(str) {
  return new Date(Date.parse(str));
};


var Showdown={};Showdown.converter=function(){var a,b,c,d=0;this.makeHtml=function(d){return a=new Array,b=new Array,c=new Array,d=d.replace(/~/g,"~T"),d=d.replace(/\$/g,"~D"),d=d.replace(/\r\n/g,"\n"),d=d.replace(/\r/g,"\n"),d="\n\n"+d+"\n\n",d=E(d),d=d.replace(/^[ \t]+$/gm,""),d=g(d),d=f(d),d=i(d),d=C(d),d=d.replace(/~D/g,"$$"),d=d.replace(/~T/g,"~")};var e,f=function(c){var c=c.replace(/^[ ]{0,3}\[(.+)\]:[ \t]*\n?[ \t]*<?(\S+?)>?[ \t]*\n?[ \t]*(?:(\n*)["(](.+?)[")][ \t]*)?(?:\n+|\Z)/gm,function(c,d,e,f,g){return d=d.toLowerCase(),a[d]=y(e),f?f+g:(g&&(b[d]=g.replace(/"/g,"&quot;")),"")});return c},g=function(a){a=a.replace(/\n/g,"\n\n");return a=a.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del)\b[^\r]*?\n<\/\2>[ \t]*(?=\n+))/gm,h),a=a.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math)\b[^\r]*?.*<\/\2>[ \t]*(?=\n+)\n)/gm,h),a=a.replace(/(\n[ ]{0,3}(<(hr)\b([^<>])*?\/?>)[ \t]*(?=\n{2,}))/g,h),a=a.replace(/(\n\n[ ]{0,3}<!(--[^\r]*?--\s*)+>[ \t]*(?=\n{2,}))/g,h),a=a.replace(/(?:\n\n)([ ]{0,3}(?:<([?%])[^\r]*?\2>)[ \t]*(?=\n{2,}))/g,h),a=a.replace(/\n\n/g,"\n")},h=function(a,b){var d=b;return d=d.replace(/\n\n/g,"\n"),d=d.replace(/^\n/,""),d=d.replace(/\n+$/g,""),d="\n\n~K"+(c.push(d)-1)+"K\n\n"},i=function(a){a=p(a);var b=s("<hr />");return a=a.replace(/^[ ]{0,2}([ ]?\*[ ]?){3,}[ \t]*$/gm,b),a=a.replace(/^[ ]{0,2}([ ]?\-[ ]?){3,}[ \t]*$/gm,b),a=a.replace(/^[ ]{0,2}([ ]?\_[ ]?){3,}[ \t]*$/gm,b),a=q(a),a=r(a),a=w(a),a=g(a),a=x(a)},j=function(a){return a=t(a),a=k(a),a=z(a),a=n(a),a=l(a),a=A(a),a=y(a),a=v(a),a=a.replace(/  +\n/g," <br />\n")},k=function(a){var b=/(<[a-z\/!$]("[^"]*"|'[^']*'|[^'">])*>|<!(--.*?--\s*)+>)/gi;return a=a.replace(b,function(a){var b=a.replace(/(.)<\/?code>(?=.)/g,"$1`");return b=F(b,"\\`*_")})},l=function(a){return a=a.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g,m),a=a.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\]\([ \t]*()<?(.*?)>?[ \t]*((['"])(.*?)\6[ \t]*)?\))/g,m),a=a.replace(/(\[([^\[\]]+)\])()()()()()/g,m)},m=function(c,d,e,f,g,h,i,j){void 0==j&&(j="");var k=d,l=e,m=f.toLowerCase(),n=g,o=j;if(""==n)if(""==m&&(m=l.toLowerCase().replace(/ ?\n/g," ")),n="#"+m,void 0!=a[m])n=a[m],void 0!=b[m]&&(o=b[m]);else{if(!(k.search(/\(\s*\)$/m)>-1))return k;n=""}n=F(n,"*_");var p='<a href="'+n+'"';return""!=o&&(o=o.replace(/"/g,"&quot;"),o=F(o,"*_"),p+=' title="'+o+'"'),p+=">"+l+"</a>"},n=function(a){return a=a.replace(/(!\[(.*?)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g,o),a=a.replace(/(!\[(.*?)\]\s?\([ \t]*()<?(\S+?)>?[ \t]*((['"])(.*?)\6[ \t]*)?\))/g,o)},o=function(c,d,e,f,g,h,i,j){var k=d,l=e,m=f.toLowerCase(),n=g,o=j;if(o||(o=""),""==n){if(""==m&&(m=l.toLowerCase().replace(/ ?\n/g," ")),n="#"+m,void 0==a[m])return k;n=a[m],void 0!=b[m]&&(o=b[m])}l=l.replace(/"/g,"&quot;"),n=F(n,"*_");var p='<img src="'+n+'" alt="'+l+'"';return o=o.replace(/"/g,"&quot;"),o=F(o,"*_"),p+=' title="'+o+'"',p+=" />"},p=function(a){return a=a.replace(/^(.+)[ \t]*\n=+[ \t]*\n+/gm,function(a,b){return s("<h1>"+j(b)+"</h1>")}),a=a.replace(/^(.+)[ \t]*\n-+[ \t]*\n+/gm,function(a,b){return s("<h2>"+j(b)+"</h2>")}),a=a.replace(/^(\#{1,6})[ \t]*(.+?)[ \t]*\#*\n+/gm,function(a,b,c){var d=b.length;return s("<h"+d+">"+j(c)+"</h"+d+">")})},q=function(a){a+="~0";var b=/^(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/gm;return d?a=a.replace(b,function(a,b,c){var d=b,f=c.search(/[*+-]/g)>-1?"ul":"ol";d=d.replace(/\n{2,}/g,"\n\n\n");var g=e(d);return g=g.replace(/\s+$/,""),g="<"+f+">"+g+"</"+f+">\n"}):(b=/(\n\n|^\n?)(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/g,a=a.replace(b,function(a,b,c,d){var f=b,g=c,h=d.search(/[*+-]/g)>-1?"ul":"ol",g=g.replace(/\n{2,}/g,"\n\n\n"),i=e(g);return i=f+"<"+h+">\n"+i+"</"+h+">\n"})),a=a.replace(/~0/,"")};e=function(a){return d++,a=a.replace(/\n{2,}$/,"\n"),a+="~0",a=a.replace(/(\n)?(^[ \t]*)([*+-]|\d+[.])[ \t]+([^\r]+?(\n{1,2}))(?=\n*(~0|\2([*+-]|\d+[.])[ \t]+))/gm,function(a,b,c,d,e){var f=e,g=b;return g||f.search(/\n{2,}/)>-1?f=i(D(f)):(f=q(D(f)),f=f.replace(/\n$/,""),f=j(f)),"<li>"+f+"</li>\n"}),a=a.replace(/~0/g,""),d--,a};var r=function(a){return a+="~0",a=a.replace(/(?:\n\n|^)((?:(?:[ ]{4}|\t).*\n+)+)(\n*[ ]{0,3}[^ \t\n]|(?=~0))/g,function(a,b,c){var d=b,e=c;return d=u(D(d)),d=E(d),d=d.replace(/^\n+/g,""),d=d.replace(/\n+$/g,""),d="<pre><code>"+d+"\n</code></pre>",s(d)+e}),a=a.replace(/~0/,"")},s=function(a){return a=a.replace(/(^\n+|\n+$)/g,""),"\n\n~K"+(c.push(a)-1)+"K\n\n"},t=function(a){return a=a.replace(/(^|[^\\])(`+)([^\r]*?[^`])\2(?!`)/gm,function(a,b,c,d){var e=d;return e=e.replace(/^([ \t]*)/g,""),e=e.replace(/[ \t]*$/g,""),e=u(e),b+"<code>"+e+"</code>"})},u=function(a){return a=a.replace(/&/g,"&amp;"),a=a.replace(/</g,"&lt;"),a=a.replace(/>/g,"&gt;"),a=F(a,"*_{}[]\\",!1)},v=function(a){return a=a.replace(/(\*\*|__)(?=\S)([^\r]*?\S[*_]*)\1/g,"<strong>$2</strong>"),a=a.replace(/(\*|_)(?=\S)([^\r]*?\S)\1/g,"<em>$2</em>")},w=function(a){return a=a.replace(/((^[ \t]*>[ \t]?.+\n(.+\n)*\n*)+)/gm,function(a,b){var c=b;return c=c.replace(/^[ \t]*>[ \t]?/gm,"~0"),c=c.replace(/~0/g,""),c=c.replace(/^[ \t]+$/gm,""),c=i(c),c=c.replace(/(^|\n)/g,"$1  "),c=c.replace(/(\s*<pre>[^\r]+?<\/pre>)/gm,function(a,b){var c=b;return c=c.replace(/^  /gm,"~0"),c=c.replace(/~0/g,"")}),s("<blockquote>\n"+c+"\n</blockquote>")})},x=function(a){a=a.replace(/^\n+/g,""),a=a.replace(/\n+$/g,"");for(var b=a.split(/\n{2,}/g),d=new Array,e=b.length,f=0;e>f;f++){var g=b[f];g.search(/~K(\d+)K/g)>=0?d.push(g):g.search(/\S/)>=0&&(g=j(g),g=g.replace(/^([ \t]*)/g,"<p>"),g+="</p>",d.push(g))}e=d.length;for(var f=0;e>f;f++)for(;d[f].search(/~K(\d+)K/)>=0;){var h=c[RegExp.$1];h=h.replace(/\$/g,"$$$$"),d[f]=d[f].replace(/~K\d+K/,h)}return d.join("\n\n")},y=function(a){return a=a.replace(/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/g,"&amp;"),a=a.replace(/<(?![a-z\/?\$!])/gi,"&lt;")},z=function(a){return a=a.replace(/\\(\\)/g,G),a=a.replace(/\\([`*_{}\[\]()>#+-.!])/g,G)},A=function(a){return a=a.replace(/<((https?|ftp|dict):[^'">\s]+)>/gi,'<a href="$1">$1</a>'),a=a.replace(/<(?:mailto:)?([-.\w]+\@[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+)>/gi,function(a,b){return B(C(b))})},B=function(a){function b(a){var b="0123456789ABCDEF",c=a.charCodeAt(0);return b.charAt(c>>4)+b.charAt(15&c)}var c=[function(a){return"&#"+a.charCodeAt(0)+";"},function(a){return"&#x"+b(a)+";"},function(a){return a}];return a="mailto:"+a,a=a.replace(/./g,function(a){if("@"==a)a=c[Math.floor(2*Math.random())](a);else if(":"!=a){var b=Math.random();a=b>.9?c[2](a):b>.45?c[1](a):c[0](a)}return a}),a='<a href="'+a+'">'+a+"</a>",a=a.replace(/">.+:/g,'">')},C=function(a){return a=a.replace(/~E(\d+)E/g,function(a,b){var c=parseInt(b);return String.fromCharCode(c)})},D=function(a){return a=a.replace(/^(\t|[ ]{1,4})/gm,"~0"),a=a.replace(/~0/g,"")},E=function(a){return a=a.replace(/\t(?=\t)/g,"    "),a=a.replace(/\t/g,"~A~B"),a=a.replace(/~B(.+?)~A/g,function(a,b){for(var c=b,d=4-c.length%4,e=0;d>e;e++)c+=" ";return c}),a=a.replace(/~A/g,"    "),a=a.replace(/~B/g,"")},F=function(a,b,c){var d="(["+b.replace(/([\[\]\\])/g,"\\$1")+"])";c&&(d="\\\\"+d);var e=new RegExp(d,"g");return a=a.replace(e,G)},G=function(a,b){var c=b.charCodeAt(0);return"~E"+c+"E"}};

/*
CryptoJS v3.1.2
code.google.com/p/crypto-js
(c) 2009-2013 by Jeff Mott. All rights reserved.
code.google.com/p/crypto-js/wiki/License
*/
var CryptoJS=CryptoJS||function(u,p){var d={},l=d.lib={},s=function(){},t=l.Base={extend:function(a){s.prototype=this;var c=new s;a&&c.mixIn(a);c.hasOwnProperty("init")||(c.init=function(){c.$super.init.apply(this,arguments)});c.init.prototype=c;c.$super=this;return c},create:function(){var a=this.extend();a.init.apply(a,arguments);return a},init:function(){},mixIn:function(a){for(var c in a)a.hasOwnProperty(c)&&(this[c]=a[c]);a.hasOwnProperty("toString")&&(this.toString=a.toString)},clone:function(){return this.init.prototype.extend(this)}},
r=l.WordArray=t.extend({init:function(a,c){a=this.words=a||[];this.sigBytes=c!=p?c:4*a.length},toString:function(a){return(a||v).stringify(this)},concat:function(a){var c=this.words,e=a.words,j=this.sigBytes;a=a.sigBytes;this.clamp();if(j%4)for(var k=0;k<a;k++)c[j+k>>>2]|=(e[k>>>2]>>>24-8*(k%4)&255)<<24-8*((j+k)%4);else if(65535<e.length)for(k=0;k<a;k+=4)c[j+k>>>2]=e[k>>>2];else c.push.apply(c,e);this.sigBytes+=a;return this},clamp:function(){var a=this.words,c=this.sigBytes;a[c>>>2]&=4294967295<<
32-8*(c%4);a.length=u.ceil(c/4)},clone:function(){var a=t.clone.call(this);a.words=this.words.slice(0);return a},random:function(a){for(var c=[],e=0;e<a;e+=4)c.push(4294967296*u.random()|0);return new r.init(c,a)}}),w=d.enc={},v=w.Hex={stringify:function(a){var c=a.words;a=a.sigBytes;for(var e=[],j=0;j<a;j++){var k=c[j>>>2]>>>24-8*(j%4)&255;e.push((k>>>4).toString(16));e.push((k&15).toString(16))}return e.join("")},parse:function(a){for(var c=a.length,e=[],j=0;j<c;j+=2)e[j>>>3]|=parseInt(a.substr(j,
2),16)<<24-4*(j%8);return new r.init(e,c/2)}},b=w.Latin1={stringify:function(a){var c=a.words;a=a.sigBytes;for(var e=[],j=0;j<a;j++)e.push(String.fromCharCode(c[j>>>2]>>>24-8*(j%4)&255));return e.join("")},parse:function(a){for(var c=a.length,e=[],j=0;j<c;j++)e[j>>>2]|=(a.charCodeAt(j)&255)<<24-8*(j%4);return new r.init(e,c)}},x=w.Utf8={stringify:function(a){try{return decodeURIComponent(escape(b.stringify(a)))}catch(c){throw Error("Malformed UTF-8 data");}},parse:function(a){return b.parse(unescape(encodeURIComponent(a)))}},
q=l.BufferedBlockAlgorithm=t.extend({reset:function(){this._data=new r.init;this._nDataBytes=0},_append:function(a){"string"==typeof a&&(a=x.parse(a));this._data.concat(a);this._nDataBytes+=a.sigBytes},_process:function(a){var c=this._data,e=c.words,j=c.sigBytes,k=this.blockSize,b=j/(4*k),b=a?u.ceil(b):u.max((b|0)-this._minBufferSize,0);a=b*k;j=u.min(4*a,j);if(a){for(var q=0;q<a;q+=k)this._doProcessBlock(e,q);q=e.splice(0,a);c.sigBytes-=j}return new r.init(q,j)},clone:function(){var a=t.clone.call(this);
a._data=this._data.clone();return a},_minBufferSize:0});l.Hasher=q.extend({cfg:t.extend(),init:function(a){this.cfg=this.cfg.extend(a);this.reset()},reset:function(){q.reset.call(this);this._doReset()},update:function(a){this._append(a);this._process();return this},finalize:function(a){a&&this._append(a);return this._doFinalize()},blockSize:16,_createHelper:function(a){return function(b,e){return(new a.init(e)).finalize(b)}},_createHmacHelper:function(a){return function(b,e){return(new n.HMAC.init(a,
e)).finalize(b)}}});var n=d.algo={};return d}(Math);
(function(){var u=CryptoJS,p=u.lib.WordArray;u.enc.Base64={stringify:function(d){var l=d.words,p=d.sigBytes,t=this._map;d.clamp();d=[];for(var r=0;r<p;r+=3)for(var w=(l[r>>>2]>>>24-8*(r%4)&255)<<16|(l[r+1>>>2]>>>24-8*((r+1)%4)&255)<<8|l[r+2>>>2]>>>24-8*((r+2)%4)&255,v=0;4>v&&r+0.75*v<p;v++)d.push(t.charAt(w>>>6*(3-v)&63));if(l=t.charAt(64))for(;d.length%4;)d.push(l);return d.join("")},parse:function(d){var l=d.length,s=this._map,t=s.charAt(64);t&&(t=d.indexOf(t),-1!=t&&(l=t));for(var t=[],r=0,w=0;w<
l;w++)if(w%4){var v=s.indexOf(d.charAt(w-1))<<2*(w%4),b=s.indexOf(d.charAt(w))>>>6-2*(w%4);t[r>>>2]|=(v|b)<<24-8*(r%4);r++}return p.create(t,r)},_map:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="}})();
(function(u){function p(b,n,a,c,e,j,k){b=b+(n&a|~n&c)+e+k;return(b<<j|b>>>32-j)+n}function d(b,n,a,c,e,j,k){b=b+(n&c|a&~c)+e+k;return(b<<j|b>>>32-j)+n}function l(b,n,a,c,e,j,k){b=b+(n^a^c)+e+k;return(b<<j|b>>>32-j)+n}function s(b,n,a,c,e,j,k){b=b+(a^(n|~c))+e+k;return(b<<j|b>>>32-j)+n}for(var t=CryptoJS,r=t.lib,w=r.WordArray,v=r.Hasher,r=t.algo,b=[],x=0;64>x;x++)b[x]=4294967296*u.abs(u.sin(x+1))|0;r=r.MD5=v.extend({_doReset:function(){this._hash=new w.init([1732584193,4023233417,2562383102,271733878])},
_doProcessBlock:function(q,n){for(var a=0;16>a;a++){var c=n+a,e=q[c];q[c]=(e<<8|e>>>24)&16711935|(e<<24|e>>>8)&4278255360}var a=this._hash.words,c=q[n+0],e=q[n+1],j=q[n+2],k=q[n+3],z=q[n+4],r=q[n+5],t=q[n+6],w=q[n+7],v=q[n+8],A=q[n+9],B=q[n+10],C=q[n+11],u=q[n+12],D=q[n+13],E=q[n+14],x=q[n+15],f=a[0],m=a[1],g=a[2],h=a[3],f=p(f,m,g,h,c,7,b[0]),h=p(h,f,m,g,e,12,b[1]),g=p(g,h,f,m,j,17,b[2]),m=p(m,g,h,f,k,22,b[3]),f=p(f,m,g,h,z,7,b[4]),h=p(h,f,m,g,r,12,b[5]),g=p(g,h,f,m,t,17,b[6]),m=p(m,g,h,f,w,22,b[7]),
f=p(f,m,g,h,v,7,b[8]),h=p(h,f,m,g,A,12,b[9]),g=p(g,h,f,m,B,17,b[10]),m=p(m,g,h,f,C,22,b[11]),f=p(f,m,g,h,u,7,b[12]),h=p(h,f,m,g,D,12,b[13]),g=p(g,h,f,m,E,17,b[14]),m=p(m,g,h,f,x,22,b[15]),f=d(f,m,g,h,e,5,b[16]),h=d(h,f,m,g,t,9,b[17]),g=d(g,h,f,m,C,14,b[18]),m=d(m,g,h,f,c,20,b[19]),f=d(f,m,g,h,r,5,b[20]),h=d(h,f,m,g,B,9,b[21]),g=d(g,h,f,m,x,14,b[22]),m=d(m,g,h,f,z,20,b[23]),f=d(f,m,g,h,A,5,b[24]),h=d(h,f,m,g,E,9,b[25]),g=d(g,h,f,m,k,14,b[26]),m=d(m,g,h,f,v,20,b[27]),f=d(f,m,g,h,D,5,b[28]),h=d(h,f,
m,g,j,9,b[29]),g=d(g,h,f,m,w,14,b[30]),m=d(m,g,h,f,u,20,b[31]),f=l(f,m,g,h,r,4,b[32]),h=l(h,f,m,g,v,11,b[33]),g=l(g,h,f,m,C,16,b[34]),m=l(m,g,h,f,E,23,b[35]),f=l(f,m,g,h,e,4,b[36]),h=l(h,f,m,g,z,11,b[37]),g=l(g,h,f,m,w,16,b[38]),m=l(m,g,h,f,B,23,b[39]),f=l(f,m,g,h,D,4,b[40]),h=l(h,f,m,g,c,11,b[41]),g=l(g,h,f,m,k,16,b[42]),m=l(m,g,h,f,t,23,b[43]),f=l(f,m,g,h,A,4,b[44]),h=l(h,f,m,g,u,11,b[45]),g=l(g,h,f,m,x,16,b[46]),m=l(m,g,h,f,j,23,b[47]),f=s(f,m,g,h,c,6,b[48]),h=s(h,f,m,g,w,10,b[49]),g=s(g,h,f,m,
E,15,b[50]),m=s(m,g,h,f,r,21,b[51]),f=s(f,m,g,h,u,6,b[52]),h=s(h,f,m,g,k,10,b[53]),g=s(g,h,f,m,B,15,b[54]),m=s(m,g,h,f,e,21,b[55]),f=s(f,m,g,h,v,6,b[56]),h=s(h,f,m,g,x,10,b[57]),g=s(g,h,f,m,t,15,b[58]),m=s(m,g,h,f,D,21,b[59]),f=s(f,m,g,h,z,6,b[60]),h=s(h,f,m,g,C,10,b[61]),g=s(g,h,f,m,j,15,b[62]),m=s(m,g,h,f,A,21,b[63]);a[0]=a[0]+f|0;a[1]=a[1]+m|0;a[2]=a[2]+g|0;a[3]=a[3]+h|0},_doFinalize:function(){var b=this._data,n=b.words,a=8*this._nDataBytes,c=8*b.sigBytes;n[c>>>5]|=128<<24-c%32;var e=u.floor(a/
4294967296);n[(c+64>>>9<<4)+15]=(e<<8|e>>>24)&16711935|(e<<24|e>>>8)&4278255360;n[(c+64>>>9<<4)+14]=(a<<8|a>>>24)&16711935|(a<<24|a>>>8)&4278255360;b.sigBytes=4*(n.length+1);this._process();b=this._hash;n=b.words;for(a=0;4>a;a++)c=n[a],n[a]=(c<<8|c>>>24)&16711935|(c<<24|c>>>8)&4278255360;return b},clone:function(){var b=v.clone.call(this);b._hash=this._hash.clone();return b}});t.MD5=v._createHelper(r);t.HmacMD5=v._createHmacHelper(r)})(Math);
(function(){var u=CryptoJS,p=u.lib,d=p.Base,l=p.WordArray,p=u.algo,s=p.EvpKDF=d.extend({cfg:d.extend({keySize:4,hasher:p.MD5,iterations:1}),init:function(d){this.cfg=this.cfg.extend(d)},compute:function(d,r){for(var p=this.cfg,s=p.hasher.create(),b=l.create(),u=b.words,q=p.keySize,p=p.iterations;u.length<q;){n&&s.update(n);var n=s.update(d).finalize(r);s.reset();for(var a=1;a<p;a++)n=s.finalize(n),s.reset();b.concat(n)}b.sigBytes=4*q;return b}});u.EvpKDF=function(d,l,p){return s.create(p).compute(d,
l)}})();
CryptoJS.lib.Cipher||function(u){var p=CryptoJS,d=p.lib,l=d.Base,s=d.WordArray,t=d.BufferedBlockAlgorithm,r=p.enc.Base64,w=p.algo.EvpKDF,v=d.Cipher=t.extend({cfg:l.extend(),createEncryptor:function(e,a){return this.create(this._ENC_XFORM_MODE,e,a)},createDecryptor:function(e,a){return this.create(this._DEC_XFORM_MODE,e,a)},init:function(e,a,b){this.cfg=this.cfg.extend(b);this._xformMode=e;this._key=a;this.reset()},reset:function(){t.reset.call(this);this._doReset()},process:function(e){this._append(e);return this._process()},
finalize:function(e){e&&this._append(e);return this._doFinalize()},keySize:4,ivSize:4,_ENC_XFORM_MODE:1,_DEC_XFORM_MODE:2,_createHelper:function(e){return{encrypt:function(b,k,d){return("string"==typeof k?c:a).encrypt(e,b,k,d)},decrypt:function(b,k,d){return("string"==typeof k?c:a).decrypt(e,b,k,d)}}}});d.StreamCipher=v.extend({_doFinalize:function(){return this._process(!0)},blockSize:1});var b=p.mode={},x=function(e,a,b){var c=this._iv;c?this._iv=u:c=this._prevBlock;for(var d=0;d<b;d++)e[a+d]^=
c[d]},q=(d.BlockCipherMode=l.extend({createEncryptor:function(e,a){return this.Encryptor.create(e,a)},createDecryptor:function(e,a){return this.Decryptor.create(e,a)},init:function(e,a){this._cipher=e;this._iv=a}})).extend();q.Encryptor=q.extend({processBlock:function(e,a){var b=this._cipher,c=b.blockSize;x.call(this,e,a,c);b.encryptBlock(e,a);this._prevBlock=e.slice(a,a+c)}});q.Decryptor=q.extend({processBlock:function(e,a){var b=this._cipher,c=b.blockSize,d=e.slice(a,a+c);b.decryptBlock(e,a);x.call(this,
e,a,c);this._prevBlock=d}});b=b.CBC=q;q=(p.pad={}).Pkcs7={pad:function(a,b){for(var c=4*b,c=c-a.sigBytes%c,d=c<<24|c<<16|c<<8|c,l=[],n=0;n<c;n+=4)l.push(d);c=s.create(l,c);a.concat(c)},unpad:function(a){a.sigBytes-=a.words[a.sigBytes-1>>>2]&255}};d.BlockCipher=v.extend({cfg:v.cfg.extend({mode:b,padding:q}),reset:function(){v.reset.call(this);var a=this.cfg,b=a.iv,a=a.mode;if(this._xformMode==this._ENC_XFORM_MODE)var c=a.createEncryptor;else c=a.createDecryptor,this._minBufferSize=1;this._mode=c.call(a,
this,b&&b.words)},_doProcessBlock:function(a,b){this._mode.processBlock(a,b)},_doFinalize:function(){var a=this.cfg.padding;if(this._xformMode==this._ENC_XFORM_MODE){a.pad(this._data,this.blockSize);var b=this._process(!0)}else b=this._process(!0),a.unpad(b);return b},blockSize:4});var n=d.CipherParams=l.extend({init:function(a){this.mixIn(a)},toString:function(a){return(a||this.formatter).stringify(this)}}),b=(p.format={}).OpenSSL={stringify:function(a){var b=a.ciphertext;a=a.salt;return(a?s.create([1398893684,
1701076831]).concat(a).concat(b):b).toString(r)},parse:function(a){a=r.parse(a);var b=a.words;if(1398893684==b[0]&&1701076831==b[1]){var c=s.create(b.slice(2,4));b.splice(0,4);a.sigBytes-=16}return n.create({ciphertext:a,salt:c})}},a=d.SerializableCipher=l.extend({cfg:l.extend({format:b}),encrypt:function(a,b,c,d){d=this.cfg.extend(d);var l=a.createEncryptor(c,d);b=l.finalize(b);l=l.cfg;return n.create({ciphertext:b,key:c,iv:l.iv,algorithm:a,mode:l.mode,padding:l.padding,blockSize:a.blockSize,formatter:d.format})},
decrypt:function(a,b,c,d){d=this.cfg.extend(d);b=this._parse(b,d.format);return a.createDecryptor(c,d).finalize(b.ciphertext)},_parse:function(a,b){return"string"==typeof a?b.parse(a,this):a}}),p=(p.kdf={}).OpenSSL={execute:function(a,b,c,d){d||(d=s.random(8));a=w.create({keySize:b+c}).compute(a,d);c=s.create(a.words.slice(b),4*c);a.sigBytes=4*b;return n.create({key:a,iv:c,salt:d})}},c=d.PasswordBasedCipher=a.extend({cfg:a.cfg.extend({kdf:p}),encrypt:function(b,c,d,l){l=this.cfg.extend(l);d=l.kdf.execute(d,
b.keySize,b.ivSize);l.iv=d.iv;b=a.encrypt.call(this,b,c,d.key,l);b.mixIn(d);return b},decrypt:function(b,c,d,l){l=this.cfg.extend(l);c=this._parse(c,l.format);d=l.kdf.execute(d,b.keySize,b.ivSize,c.salt);l.iv=d.iv;return a.decrypt.call(this,b,c,d.key,l)}})}();
(function(){for(var u=CryptoJS,p=u.lib.BlockCipher,d=u.algo,l=[],s=[],t=[],r=[],w=[],v=[],b=[],x=[],q=[],n=[],a=[],c=0;256>c;c++)a[c]=128>c?c<<1:c<<1^283;for(var e=0,j=0,c=0;256>c;c++){var k=j^j<<1^j<<2^j<<3^j<<4,k=k>>>8^k&255^99;l[e]=k;s[k]=e;var z=a[e],F=a[z],G=a[F],y=257*a[k]^16843008*k;t[e]=y<<24|y>>>8;r[e]=y<<16|y>>>16;w[e]=y<<8|y>>>24;v[e]=y;y=16843009*G^65537*F^257*z^16843008*e;b[k]=y<<24|y>>>8;x[k]=y<<16|y>>>16;q[k]=y<<8|y>>>24;n[k]=y;e?(e=z^a[a[a[G^z]]],j^=a[a[j]]):e=j=1}var H=[0,1,2,4,8,
16,32,64,128,27,54],d=d.AES=p.extend({_doReset:function(){for(var a=this._key,c=a.words,d=a.sigBytes/4,a=4*((this._nRounds=d+6)+1),e=this._keySchedule=[],j=0;j<a;j++)if(j<d)e[j]=c[j];else{var k=e[j-1];j%d?6<d&&4==j%d&&(k=l[k>>>24]<<24|l[k>>>16&255]<<16|l[k>>>8&255]<<8|l[k&255]):(k=k<<8|k>>>24,k=l[k>>>24]<<24|l[k>>>16&255]<<16|l[k>>>8&255]<<8|l[k&255],k^=H[j/d|0]<<24);e[j]=e[j-d]^k}c=this._invKeySchedule=[];for(d=0;d<a;d++)j=a-d,k=d%4?e[j]:e[j-4],c[d]=4>d||4>=j?k:b[l[k>>>24]]^x[l[k>>>16&255]]^q[l[k>>>
8&255]]^n[l[k&255]]},encryptBlock:function(a,b){this._doCryptBlock(a,b,this._keySchedule,t,r,w,v,l)},decryptBlock:function(a,c){var d=a[c+1];a[c+1]=a[c+3];a[c+3]=d;this._doCryptBlock(a,c,this._invKeySchedule,b,x,q,n,s);d=a[c+1];a[c+1]=a[c+3];a[c+3]=d},_doCryptBlock:function(a,b,c,d,e,j,l,f){for(var m=this._nRounds,g=a[b]^c[0],h=a[b+1]^c[1],k=a[b+2]^c[2],n=a[b+3]^c[3],p=4,r=1;r<m;r++)var q=d[g>>>24]^e[h>>>16&255]^j[k>>>8&255]^l[n&255]^c[p++],s=d[h>>>24]^e[k>>>16&255]^j[n>>>8&255]^l[g&255]^c[p++],t=
d[k>>>24]^e[n>>>16&255]^j[g>>>8&255]^l[h&255]^c[p++],n=d[n>>>24]^e[g>>>16&255]^j[h>>>8&255]^l[k&255]^c[p++],g=q,h=s,k=t;q=(f[g>>>24]<<24|f[h>>>16&255]<<16|f[k>>>8&255]<<8|f[n&255])^c[p++];s=(f[h>>>24]<<24|f[k>>>16&255]<<16|f[n>>>8&255]<<8|f[g&255])^c[p++];t=(f[k>>>24]<<24|f[n>>>16&255]<<16|f[g>>>8&255]<<8|f[h&255])^c[p++];n=(f[n>>>24]<<24|f[g>>>16&255]<<16|f[h>>>8&255]<<8|f[k&255])^c[p++];a[b]=q;a[b+1]=s;a[b+2]=t;a[b+3]=n},keySize:8});u.AES=p._createHelper(d)})();


lastVersion = JSON.parse(GM_getValue('version', '99.beta'));

GM_setValue('version', '99.beta');

userData = null;

lastUpdated = 0;

modifyPage = function() {
  var cssClass, extraClasses, i, mmmOptions, mmmToolsFind, sub, thisLounge, tip, user;
  mmmOptions = function() {
    $('link[rel="stylesheet"], style').remove();
    $('body').html('<h1>MegaMegaMonitor Options/Tools</h1><p>For MegaMegaMonitor help, see <a href="/r/MegaMegaMonitor">/r/MegaMegaMonitor</a>.</p><h2>Options</h2><p>No options yet. Coming soon!</p><h2>Tools</h2><h3>Find highest post by a user</h3><p>Looking to gild someone in their "highest" MegaLounge? Or just trying to find a comment somebody made, once? This tool will help (but it\'s super slow!).</p><p>Username: <input type="text" id="mmm-tools-find-comment-username" value="avapoet" /> | Subreddit: <input type="text" id="mmm-tools-find-comment-subreddit" value="MegaMegaMonitor" /> | Find: <select id="mmm-tools-find-comment-type"><option value="">Any</option><option value="submitted">Post</option><option value="comments">Comment</option></select> <button id="mmm-tools-find-comment-submit">Search</button></p><hr /><p><a href="' + window.location.href + '">Back to Reddit</a></p>');
    $('#mmm-tools-find-comment-submit').click(function() {
      window.mmm_tools_find_comment_username = $('#mmm-tools-find-comment-username').val();
      window.mmm_tools_find_comment_subreddit = $('#mmm-tools-find-comment-subreddit').val().toLowerCase();
      window.mmm_tools_find_comment_type = $('#mmm-tools-find-comment-type').val();
      window.mmm_tools_find_comment_after = '';
      window.mmm_tools_find_comment_scanned = 0;
      window.mmm_tools_find_comment_cancel = false;
      $('body').html('<h1>MegaMegaMonitor Options/Tools</h1><h2>Searching...</h2><p><a href="#" id="mmm-search-cancel">Stop searching</a>. <a href="' + window.location.href + '">Back to Reddit</a>.</p><p id="mmm-search-progress">0 possibilities scanned</p><ul id="mmm-search-results"></ul>');
      $('#mmm-search-cancel').click(function() {
        window.mmm_tools_find_comment_cancel = true;
        return false;
      });
      mmmToolsFind();
    });
    return false;
  };
  mmmToolsFind = function() {
    var url;
    if (window.mmm_tools_find_comment_cancel) {
      return false;
    }
    url = '/user/' + window.mmm_tools_find_comment_username + '/' + window.mmm_tools_find_comment_type + '.json?limit=100&after=' + window.mmm_tools_find_comment_after;
    GM_xmlhttpRequest({
      method: 'GET',
      url: url,
      onload: function(resp1) {
        var json;
        if (window.mmm_tools_find_comment_cancel) {
          return false;
        }
        json = JSON.parse(resp1.responseText);
        window.mmm_tools_find_comment_after = json.data.after;
        window.mmm_tools_find_comment_scanned += json.data.children.length;
        json.data.children.forEach(function(child) {
          var created_at_friendly;
          if (child.data.subreddit.toLowerCase() === window.mmm_tools_find_comment_subreddit) {
            created_at_friendly = new Date(child.data.created_utc * 1000).toString();
            if (child.data.name.search(/^t1_/) === 0) {
              $('#mmm-search-results').append('<li><a href="' + child.data.link_url + child.data.name + '#siteTable_' + child.data.name + '">Comment on ' + child.data.link_title + '</a> (' + created_at_friendly + ')</li>');
            } else {
              $('#mmm-search-results').append('<li><a href="' + child.data.permalink + '">' + child.data.title + '</a> (' + created_at_friendly + ')</li>');
            }
          }
        });
        $('#mmm-search-progress').text('' + window.mmm_tools_find_comment_scanned + ' possibilities scanned');
        if (json.data.after === null) {
          window.mmm_tools_find_comment_cancel = true;
        } else {
          setTimeout(mmmToolsFind, 2000);
        }
      }
    });
  };
  if ($('#mmm-id').length === 0) {
    $('#header-bottom-right .user').before('<span id="mmm-id" style="margin-right: 8px;">MMM</span>');
    $('#mmm-id').hover((function() {
      var betweenOne, betweenThree, betweenTwo, m_l, out, w_e, w_t;
      betweenOne = indexOf.call(userData, 'createdAtEnd') >= 0 ? new Date(userData.createdAtEnd).toRelativeTime() : 'some time ago';
      betweenTwo = indexOf.call(userData, 'createdAtStart') >= 0 ? new Date(userData.createdAtStart).toRelativeTime() : 'some time ago';
      betweenThree = new Date(lastUpdated).toRelativeTime();
      out = '<div class="mmm-tip-id"><p><strong>MegaMegaMonitor</strong></p><p>You are using version 99.beta. Data was updated between ' + betweenOne + ' and ' + betweenTwo + ' and downloaded to your computer ' + betweenThree + ' (<a href="#" id="mmm-update-now">check for update?</a>). For help, see <a href="/r/MegaMegaMonitor">/r/MegaMegaMonitor</a>.</p><ul><li><a href="#" id="mmm-options">MMM Options/Tools</a></li></ul></div>';
      $(this).append(out);
      w_t = $('.mmm-tip').outerWidth();
      w_e = $(this).width();
      m_l = w_e / 2 - (w_t / 2);
      $('.mmm-tip').css('margin-left', m_l + 'px');
      $(this).removeAttr('title');
      $('.mmm-tip').fadeIn(200);
    }), function() {
      setTimeout((function() {
        $('.mmm-tip-id').remove();
      }), 8000);
    });
    $('#mmm-id').on('click', '#mmm-update-now', function() {
      $('#mmm-id').text('MMM updating...');
      updateUserData();
      return false;
    }).on('click', '#mmm-options', mmmOptions);
  }
  if (debugMode) {
    console.log('MegaMegaMonitor Debug: modifyPage()');
  }
  if ($('.sitetable a.author:not(.mmm-ran)').length === 0) {
    setTimeout(modifyPage, 2500);
    return false;
  }
  thisLounge = ($('#header-img').attr('alt') || '').toLowerCase();
  if (debugMode) {
    console.log('MegaMegaMonitor Debug: modifyPage() - tidying up');
  }
  $('.mmm-icon').remove();
  $('.content a.author.mmm-ran').removeClass('mmm-ran');
  for (user in userData.users) {
    for (i in userData.users[user]) {
      cssClass = userData.users[user][i][0];
      tip = userData.users[user][i][1];
      sub = userData.users[user][i][2];
      extraClasses = '';
      if (tip.toLowerCase() === thisLounge) {
        extraClasses += ' mmm-icon-current';
      }
      if (debugMode) {
        console.log('MegaMegaMonitor Debug: modifyPage() - ' + user + ' ' + cssClass);
      }
      $('.sitetable a.author[href$=\'/user/' + user + '\']:not(.mmm-ran)').after('<span data-sub="' + sub + '" data-tip="' + tip + '" class="mmm-icon ' + cssClass + extraClasses + '"></span>');
    }
  }
  $('.mmm-icon').hover((function() {
    var desc, m_l, out, w_e, w_t;
    desc = $(this).data('tip');
    if (desc.match(/-plus$/)) {
      desc = 'Higher than ' + desc.substr(0, desc.length - 5);
    }
    if ($(this).hasClass('mmm-icon-current')) {
      desc += ' (current)';
    }
    out = '<div class="mmm-tip">' + desc + '</div>';
    $(this).append(out);
    w_t = $('.mmm-tip').outerWidth();
    w_e = $(this).width();
    m_l = w_e / 2 - (w_t / 2);
    $('.mmm-tip').css('margin-left', m_l + 'px');
    $(this).removeAttr('title');
    $('.mmm-tip').fadeIn(200);
  }), function() {
    $('.mmm-tip').remove();
  }).dblclick(function() {
    var sub;
    sub = $(this).data('sub');
    if (sub !== '') {
      window.location.href = '/r/' + sub;
    }
  });
  $('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').each(function() {
    var i;
    var ciphertext, container, converter, err, html, key, plaintext;
    ciphertext = $(this).attr('title').split(':');
    key = '';
    i = 0;
    while (i < userData.mySubreddits.length) {
      if (userData.mySubreddits[i].id === ciphertext[0]) {
        key = userData.mySubreddits[i].crypto;
      }
      i++;
    }
    if (key !== '') {
      if ($(this).next().hasClass('keyNavAnnotation')) {
        $(this).next().remove();
      }
      container = $(this).closest('p');
      try {
        plaintext = CryptoJS.AES.decrypt(ciphertext[1], key).toString(CryptoJS.enc.Utf8);
        converter = new Showdown.converter;
        html = converter.makeHtml(plaintext);
        if (container.text() === $(this).text()) {
          container.replaceWith(html);
        } else {
          $(this).replaceWith(html.substring(3, html.length - 4));
        }
      } catch (_error) {
        err = _error;
        console.log('MegaMegaMonitor: Decryption error while decrypting ciphertext "' + ciphertext[1] + '" using key #' + ciphertext[0] + ': ' + err);
      }
    } else {
      $(this).removeAttr('title');
    }
  });
  $('.sitetable a.author').addClass('mmm-ran');
  setTimeout(modifyPage, 2500);
};

updateUserData = function() {
  if (debugMode) {
    console.log('MegaMegaMonitor Debug: updateUserData()');
  }
  GM_xmlhttpRequest({
    method: 'GET',
    url: '/api/me.json',
    onload: function(resp1) {
      var data, username;
      username = JSON.parse(resp1.responseText).data.name;
      data = 'username=' + username;
      if (debugMode) {
        console.log('POST https://danq.me/megamegamonitor/get_users.php ' + data);
      }
      GM_xmlhttpRequest({
        method: 'POST',
        url: 'https://danq.me/megamegamonitor/get_users.php',
        data: data,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        onload: function(resp2) {
          if (debugMode) {
            console.log('MegaMegaMonitor Debug: updateUserData() - response received');
          }
          userData = JSON.parse(resp2.responseText);
          if (debugMode) {
            console.log(userData);
          }
          if (indexOf.call(userData, 'error') >= 0) {
            alert(userData.error);
          } else {
            GM_setValue('userData', JSON.stringify(userData));
            lastUpdated = Date.now();
            GM_setValue('lastUpdated', JSON.stringify(lastUpdated));
            if (debugMode) {
              console.log('MegaMegaMonitor Debug: updateUserData() - saved new values');
            }
            $('#mmm-id').remove();
            modifyPage();
          }
        }
      });
    }
  });
};

if (lastVersion === '99.beta') {
  userData = JSON.parse(GM_getValue('userData', 'null'));
  lastUpdated = JSON.parse(GM_getValue('lastUpdated', 0));
}

dataAge = Date.now() - lastUpdated;

$('head').append('<style type="text/css">.mmm-id { cursor: help; } .mmm-tip, .mmm-tip-id { margin-top: 32px; z-index: 999999; background: none repeat scroll 0% 0% #FFF; color: #000; border: 1px solid #000; position: absolute; padding: 4px; } .mmm-tip, .mmm-tip-id a { color: #00f !important; text-decoration: underline !important; } .mmm-tip-id {  margin-top: 4px; } .mmm-tip-id p { margin: 4px 0 !important; } .mmm-tip-id * { font-size: 12px !important; line-height: 14px !important; } .mmm-tip-id strong { font-weight: bold; text-decoration: underline; } .mmm-icon { display: inline-block; width: 32px; height: 24px; background: url(https://d1wjam29zgrnhb.cloudfront.net/icons99.beta.png) no-repeat 0 0; margin: 0 1px; } .mmm-icon.mmm-icon-64 { background-position: 0 -1536px; } .mmm-icon.mmm-icon-68 { background-position: 0 -1632px; } .mmm-icon.mmm-icon-1 { background-position: 0 -24px; } .mmm-icon.mmm-icon-1.mmm-icon-current { background-position: -32px -24px; } .mmm-icon.mmm-icon-1-plus { background-position: -64px -24px; }  .mmm-icon.mmm-icon-2 { background-position: 0 -48px; } .mmm-icon.mmm-icon-2.mmm-icon-current { background-position: -32px -48px; } .mmm-icon.mmm-icon-2-plus { background-position: -64px -48px; }  .mmm-icon.mmm-icon-3 { background-position: 0 -72px; } .mmm-icon.mmm-icon-3.mmm-icon-current { background-position: -32px -72px; } .mmm-icon.mmm-icon-3-plus { background-position: -64px -72px; }  .mmm-icon.mmm-icon-4 { background-position: 0 -96px; } .mmm-icon.mmm-icon-4.mmm-icon-current { background-position: -32px -96px; } .mmm-icon.mmm-icon-4-plus { background-position: -64px -96px; }  .mmm-icon.mmm-icon-5 { background-position: 0 -120px; } .mmm-icon.mmm-icon-5.mmm-icon-current { background-position: -32px -120px; } .mmm-icon.mmm-icon-5-plus { background-position: -64px -120px; }  .mmm-icon.mmm-icon-6 { background-position: 0 -144px; } .mmm-icon.mmm-icon-6.mmm-icon-current { background-position: -32px -144px; } .mmm-icon.mmm-icon-6-plus { background-position: -64px -144px; }  .mmm-icon.mmm-icon-7 { background-position: 0 -168px; } .mmm-icon.mmm-icon-7.mmm-icon-current { background-position: -32px -168px; } .mmm-icon.mmm-icon-7-plus { background-position: -64px -168px; }  .mmm-icon.mmm-icon-8 { background-position: 0 -192px; } .mmm-icon.mmm-icon-8.mmm-icon-current { background-position: -32px -192px; } .mmm-icon.mmm-icon-8-plus { background-position: -64px -192px; }  .mmm-icon.mmm-icon-9 { background-position: 0 -216px; } .mmm-icon.mmm-icon-9.mmm-icon-current { background-position: -32px -216px; } .mmm-icon.mmm-icon-9-plus { background-position: -64px -216px; }  .mmm-icon.mmm-icon-10 { background-position: 0 -240px; } .mmm-icon.mmm-icon-10.mmm-icon-current { background-position: -32px -240px; } .mmm-icon.mmm-icon-10-plus { background-position: -64px -240px; }  .mmm-icon.mmm-icon-11 { background-position: 0 -264px; } .mmm-icon.mmm-icon-11.mmm-icon-current { background-position: -32px -264px; } .mmm-icon.mmm-icon-11-plus { background-position: -64px -264px; }  .mmm-icon.mmm-icon-12 { background-position: 0 -288px; } .mmm-icon.mmm-icon-12.mmm-icon-current { background-position: -32px -288px; } .mmm-icon.mmm-icon-12-plus { background-position: -64px -288px; }  .mmm-icon.mmm-icon-13 { background-position: 0 -312px; } .mmm-icon.mmm-icon-13.mmm-icon-current { background-position: -32px -312px; } .mmm-icon.mmm-icon-13-plus { background-position: -64px -312px; }  .mmm-icon.mmm-icon-14 { background-position: 0 -336px; } .mmm-icon.mmm-icon-14.mmm-icon-current { background-position: -32px -336px; } .mmm-icon.mmm-icon-14-plus { background-position: -64px -336px; }  .mmm-icon.mmm-icon-15 { background-position: 0 -360px; } .mmm-icon.mmm-icon-15.mmm-icon-current { background-position: -32px -360px; } .mmm-icon.mmm-icon-15-plus { background-position: -64px -360px; }  .mmm-icon.mmm-icon-16 { background-position: 0 -384px; } .mmm-icon.mmm-icon-16.mmm-icon-current { background-position: -32px -384px; } .mmm-icon.mmm-icon-16-plus { background-position: -64px -384px; }  .mmm-icon.mmm-icon-17 { background-position: 0 -408px; } .mmm-icon.mmm-icon-17.mmm-icon-current { background-position: -32px -408px; } .mmm-icon.mmm-icon-17-plus { background-position: -64px -408px; }  .mmm-icon.mmm-icon-18 { background-position: 0 -432px; } .mmm-icon.mmm-icon-18.mmm-icon-current { background-position: -32px -432px; } .mmm-icon.mmm-icon-18-plus { background-position: -64px -432px; }  .mmm-icon.mmm-icon-19 { background-position: 0 -456px; } .mmm-icon.mmm-icon-19.mmm-icon-current { background-position: -32px -456px; } .mmm-icon.mmm-icon-19-plus { background-position: -64px -456px; }  .mmm-icon.mmm-icon-20 { background-position: 0 -480px; } .mmm-icon.mmm-icon-20.mmm-icon-current { background-position: -32px -480px; } .mmm-icon.mmm-icon-20-plus { background-position: -64px -480px; }  .mmm-icon.mmm-icon-21 { background-position: 0 -504px; } .mmm-icon.mmm-icon-21.mmm-icon-current { background-position: -32px -504px; } .mmm-icon.mmm-icon-21-plus { background-position: -64px -504px; }  .mmm-icon.mmm-icon-22 { background-position: 0 -528px; } .mmm-icon.mmm-icon-22.mmm-icon-current { background-position: -32px -528px; } .mmm-icon.mmm-icon-22-plus { background-position: -64px -528px; }  .mmm-icon.mmm-icon-23 { background-position: 0 -552px; } .mmm-icon.mmm-icon-23.mmm-icon-current { background-position: -32px -552px; } .mmm-icon.mmm-icon-23-plus { background-position: -64px -552px; }  .mmm-icon.mmm-icon-24 { background-position: 0 -576px; } .mmm-icon.mmm-icon-24.mmm-icon-current { background-position: -32px -576px; } .mmm-icon.mmm-icon-24-plus { background-position: -64px -576px; }  .mmm-icon.mmm-icon-25 { background-position: 0 -600px; } .mmm-icon.mmm-icon-25.mmm-icon-current { background-position: -32px -600px; } .mmm-icon.mmm-icon-25-plus { background-position: -64px -600px; }  .mmm-icon.mmm-icon-26 { background-position: 0 -624px; } .mmm-icon.mmm-icon-26.mmm-icon-current { background-position: -32px -624px; } .mmm-icon.mmm-icon-26-plus { background-position: -64px -624px; }  .mmm-icon.mmm-icon-27 { background-position: 0 -648px; } .mmm-icon.mmm-icon-27.mmm-icon-current { background-position: -32px -648px; } .mmm-icon.mmm-icon-27-plus { background-position: -64px -648px; }  .mmm-icon.mmm-icon-28 { background-position: 0 -672px; } .mmm-icon.mmm-icon-28.mmm-icon-current { background-position: -32px -672px; } .mmm-icon.mmm-icon-28-plus { background-position: -64px -672px; }  .mmm-icon.mmm-icon-29 { background-position: 0 -696px; } .mmm-icon.mmm-icon-29.mmm-icon-current { background-position: -32px -696px; } .mmm-icon.mmm-icon-29-plus { background-position: -64px -696px; }  .mmm-icon.mmm-icon-30 { background-position: 0 -720px; } .mmm-icon.mmm-icon-30.mmm-icon-current { background-position: -32px -720px; } .mmm-icon.mmm-icon-30-plus { background-position: -64px -720px; }  .mmm-icon.mmm-icon-31 { background-position: 0 -744px; } .mmm-icon.mmm-icon-31.mmm-icon-current { background-position: -32px -744px; } .mmm-icon.mmm-icon-31-plus { background-position: -64px -744px; }  .mmm-icon.mmm-icon-32 { background-position: 0 -768px; } .mmm-icon.mmm-icon-32.mmm-icon-current { background-position: -32px -768px; } .mmm-icon.mmm-icon-32-plus { background-position: -64px -768px; }  .mmm-icon.mmm-icon-33 { background-position: 0 -792px; } .mmm-icon.mmm-icon-33.mmm-icon-current { background-position: -32px -792px; } .mmm-icon.mmm-icon-33-plus { background-position: -64px -792px; }  .mmm-icon.mmm-icon-34 { background-position: 0 -816px; } .mmm-icon.mmm-icon-34.mmm-icon-current { background-position: -32px -816px; } .mmm-icon.mmm-icon-34-plus { background-position: -64px -816px; }  .mmm-icon.mmm-icon-35 { background-position: 0 -840px; } .mmm-icon.mmm-icon-35.mmm-icon-current { background-position: -32px -840px; } .mmm-icon.mmm-icon-35-plus { background-position: -64px -840px; }  .mmm-icon.mmm-icon-36 { background-position: 0 -864px; } .mmm-icon.mmm-icon-36.mmm-icon-current { background-position: -32px -864px; } .mmm-icon.mmm-icon-36-plus { background-position: -64px -864px; }  .mmm-icon.mmm-icon-37 { background-position: 0 -888px; } .mmm-icon.mmm-icon-37.mmm-icon-current { background-position: -32px -888px; } .mmm-icon.mmm-icon-37-plus { background-position: -64px -888px; }  .mmm-icon.mmm-icon-62 { background-position: 0 -1488px; } .mmm-icon.mmm-icon-62.mmm-icon-current { background-position: -32px -1488px; } .mmm-icon.mmm-icon-62-plus { background-position: -64px -1488px; }  .mmm-icon.mmm-icon-63 { background-position: 0 -1512px; } .mmm-icon.mmm-icon-63.mmm-icon-current { background-position: -32px -1512px; } .mmm-icon.mmm-icon-63-plus { background-position: -64px -1512px; }  .mmm-icon.mmm-icon-65 { background-position: 0 -1560px; } .mmm-icon.mmm-icon-65.mmm-icon-current { background-position: -32px -1560px; } .mmm-icon.mmm-icon-65-plus { background-position: -64px -1560px; }  .mmm-icon.mmm-icon-66 { background-position: 0 -1584px; } .mmm-icon.mmm-icon-66.mmm-icon-current { background-position: -32px -1584px; } .mmm-icon.mmm-icon-66-plus { background-position: -64px -1584px; }  .mmm-icon.mmm-icon-67 { background-position: 0 -1608px; } .mmm-icon.mmm-icon-67.mmm-icon-current { background-position: -32px -1608px; } .mmm-icon.mmm-icon-67-plus { background-position: -64px -1608px; }  .mmm-icon.mmm-icon-69 { background-position: 0 -1656px; } .mmm-icon.mmm-icon-69.mmm-icon-current { background-position: -32px -1656px; } .mmm-icon.mmm-icon-69-plus { background-position: -64px -1656px; } </style>');

if ($('body').hasClass('loggedin')) {
  if (dataAge > 86400000) {
    if (debugMode) {
      console.log('MegaMegaMonitor Debug: At ' + dataAge + ' seconds old, data is out of date. Updating.');
    }
    updateUserData();
  } else {
    if (debugMode) {
      console.log('MegaMegaMonitor Debug: At ' + dataAge + ' seconds old, data is fresh. Cool.');
    }
    modifyPage();
  }
}
