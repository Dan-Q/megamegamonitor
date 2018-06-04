// ==UserScript==
// @name         MegaMegaMonitor
// @namespace    https://www.megamegamonitor.com/
// @version      121.1437492279
// @description  Spot your MegaFriends around the rest of Reddit.
// @author       Dan Q (/u/avapoet)
// @downloadURL  https://www.megamegamonitor.com/bin/MegaMegaMonitor.next.user.js?1437492280
// @require      https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js
// @include      *.reddit.com/*
// @include      *.megamegamonitor.com/*
// @include      danq.me/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// ==/UserScript==
var accesskeys, dataAge, debugMode, iconsize, lastUpdated, lastVersion, mmmChangeNinjaPirateVisibility, mmmGetNinjaPirateVisibility, mmmInvite, mmmOptions, mmmToolsFind, modifyPage, proveIdentity, suppressionList, updateUserData, userData;

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


//
// showdown.js -- A javascript port of Markdown.
//
// Copyright (c) 2007 John Fraser.
//
// Original Markdown Copyright (c) 2004-2005 John Gruber
//   <http://daringfireball.net/projects/markdown/>
//
// Redistributable under a BSD-style open source license.
// See license.txt for more information.
//
// The full source distribution is at:
//
//				A A L
//				T C A
//				T K B
//
//   <http://www.attacklab.net/>
//

//
// Wherever possible, Showdown is a straight, line-by-line port
// of the Perl version of Markdown.
//
// This is not a normal parser design; it's basically just a
// series of string substitutions.  It's hard to read and
// maintain this way,  but keeping Showdown close to the original
// design makes it easier to port new features.
//
// More importantly, Showdown behaves like markdown.pl in most
// edge cases.  So web applications can do client-side preview
// in Javascript, and then build identical HTML on the server.
//
// This port needs the new RegExp functionality of ECMA 262,
// 3rd Edition (i.e. Javascript 1.5).  Most modern web browsers
// should do fine.  Even with the new regular expression features,
// We do a lot of work to emulate Perl's regex functionality.
// The tricky changes in this file mostly have the "attacklab:"
// label.  Major or self-explanatory changes don't.
//
// Smart diff tools like Araxis Merge will be able to match up
// this file with markdown.pl in a useful way.  A little tweaking
// helps: in a copy of markdown.pl, replace "#" with "//" and
// replace "$text" with "text".  Be sure to ignore whitespace
// and line endings.
//


//
// Showdown usage:
//
//   var text = "Markdown *rocks*.";
//
//   var converter = new Showdown.converter();
//   var html = converter.makeHtml(text);
//
//   alert(html);
//
// Note: move the sample code to the bottom of this
// file before uncommenting it.
//


//
// Showdown namespace
//
var Showdown = {};

//
// converter
//
// Wraps all "globals" so that the only thing
// exposed is makeHtml().
//
Showdown.converter = function() {

//
// Globals:
//

// Global hashes, used by various utility routines
var g_urls;
var g_titles;
var g_html_blocks;

// Used to track when we're inside an ordered or unordered list
// (see _ProcessListItems() for details):
var g_list_level = 0;


this.makeHtml = function(text) {
//
// Main function. The order in which other subs are called here is
// essential. Link and image substitutions need to happen before
// _EscapeSpecialCharsWithinTagAttributes(), so that any *'s or _'s in the <a>
// and <img> tags get encoded.
//

	// Clear the global hashes. If we don't clear these, you get conflicts
	// from other articles when generating a page which contains more than
	// one article (e.g. an index page that shows the N most recent
	// articles):
	g_urls = new Array();
	g_titles = new Array();
	g_html_blocks = new Array();

	// attacklab: Replace ~ with ~T
	// This lets us use tilde as an escape char to avoid md5 hashes
	// The choice of character is arbitray; anything that isn't
    // magic in Markdown will work.
	text = text.replace(/~/g,"~T");

	// attacklab: Replace $ with ~D
	// RegExp interprets $ as a special character
	// when it's in a replacement string
	text = text.replace(/\$/g,"~D");

	// Standardize line endings
	text = text.replace(/\r\n/g,"\n"); // DOS to Unix
	text = text.replace(/\r/g,"\n"); // Mac to Unix

	// Make sure text begins and ends with a couple of newlines:
	text = "\n\n" + text + "\n\n";

	// Convert all tabs to spaces.
	text = _Detab(text);

	// Strip any lines consisting only of spaces and tabs.
	// This makes subsequent regexen easier to write, because we can
	// match consecutive blank lines with /\n+/ instead of something
	// contorted like /[ \t]*\n+/ .
	text = text.replace(/^[ \t]+$/mg,"");

	// Turn block-level HTML blocks into hash entries
	text = _HashHTMLBlocks(text);

	// Strip link definitions, store in hashes.
	text = _StripLinkDefinitions(text);

	text = _RunBlockGamut(text);

	text = _UnescapeSpecialChars(text);

	// attacklab: Restore dollar signs
	text = text.replace(/~D/g,"$$");

	// attacklab: Restore tildes
	text = text.replace(/~T/g,"~");

	return text;
}


var _StripLinkDefinitions = function(text) {
//
// Strips link definitions from text, stores the URLs and titles in
// hash references.
//

	// Link defs are in the form: ^[id]: url "optional title"

	/*
		var text = text.replace(/
				^[ ]{0,3}\[(.+)\]:  // id = $1  attacklab: g_tab_width - 1
				  [ \t]*
				  \n?				// maybe *one* newline
				  [ \t]*
				<?(\S+?)>?			// url = $2
				  [ \t]*
				  \n?				// maybe one newline
				  [ \t]*
				(?:
				  (\n*)				// any lines skipped = $3 attacklab: lookbehind removed
				  ["(]
				  (.+?)				// title = $4
				  [")]
				  [ \t]*
				)?					// title is optional
				(?:\n+|$)
			  /gm,
			  function(){...});
	*/
	var text = text.replace(/^[ ]{0,3}\[(.+)\]:[ \t]*\n?[ \t]*<?(\S+?)>?[ \t]*\n?[ \t]*(?:(\n*)["(](.+?)[")][ \t]*)?(?:\n+|\Z)/gm,
		function (wholeMatch,m1,m2,m3,m4) {
			m1 = m1.toLowerCase();
			g_urls[m1] = _EncodeAmpsAndAngles(m2);  // Link IDs are case-insensitive
			if (m3) {
				// Oops, found blank lines, so it's not a title.
				// Put back the parenthetical statement we stole.
				return m3+m4;
			} else if (m4) {
				g_titles[m1] = m4.replace(/"/g,"&quot;");
			}
			
			// Completely remove the definition from the text
			return "";
		}
	);

	return text;
}


var _HashHTMLBlocks = function(text) {
	// attacklab: Double up blank lines to reduce lookaround
	text = text.replace(/\n/g,"\n\n");

	// Hashify HTML blocks:
	// We only want to do this for block-level HTML tags, such as headers,
	// lists, and tables. That's because we still want to wrap <p>s around
	// "paragraphs" that are wrapped in non-block-level tags, such as anchors,
	// phrase emphasis, and spans. The list of tags we're looking for is
	// hard-coded:
	var block_tags_a = "p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del"
	var block_tags_b = "p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math"

	// First, look for nested blocks, e.g.:
	//   <div>
	//     <div>
	//     tags for inner block must be indented.
	//     </div>
	//   </div>
	//
	// The outermost tags must start at the left margin for this to match, and
	// the inner nested divs must be indented.
	// We need to do this before the next, more liberal match, because the next
	// match will start at the first `<div>` and stop at the first `</div>`.

	// attacklab: This regex can be expensive when it fails.
	/*
		var text = text.replace(/
		(						// save in $1
			^					// start of line  (with /m)
			<($block_tags_a)	// start tag = $2
			\b					// word break
								// attacklab: hack around khtml/pcre bug...
			[^\r]*?\n			// any number of lines, minimally matching
			</\2>				// the matching end tag
			[ \t]*				// trailing spaces/tabs
			(?=\n+)				// followed by a newline
		)						// attacklab: there are sentinel newlines at end of document
		/gm,function(){...}};
	*/
	text = text.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del)\b[^\r]*?\n<\/\2>[ \t]*(?=\n+))/gm,hashElement);

	//
	// Now match more liberally, simply from `\n<tag>` to `</tag>\n`
	//

	/*
		var text = text.replace(/
		(						// save in $1
			^					// start of line  (with /m)
			<($block_tags_b)	// start tag = $2
			\b					// word break
								// attacklab: hack around khtml/pcre bug...
			[^\r]*?				// any number of lines, minimally matching
			.*</\2>				// the matching end tag
			[ \t]*				// trailing spaces/tabs
			(?=\n+)				// followed by a newline
		)						// attacklab: there are sentinel newlines at end of document
		/gm,function(){...}};
	*/
	text = text.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math)\b[^\r]*?.*<\/\2>[ \t]*(?=\n+)\n)/gm,hashElement);

	// Special case just for <hr />. It was easier to make a special case than
	// to make the other regex more complicated.  

	/*
		text = text.replace(/
		(						// save in $1
			\n\n				// Starting after a blank line
			[ ]{0,3}
			(<(hr)				// start tag = $2
			\b					// word break
			([^<>])*?			// 
			\/?>)				// the matching end tag
			[ \t]*
			(?=\n{2,})			// followed by a blank line
		)
		/g,hashElement);
	*/
	text = text.replace(/(\n[ ]{0,3}(<(hr)\b([^<>])*?\/?>)[ \t]*(?=\n{2,}))/g,hashElement);

	// Special case for standalone HTML comments:

	/*
		text = text.replace(/
		(						// save in $1
			\n\n				// Starting after a blank line
			[ ]{0,3}			// attacklab: g_tab_width - 1
			<!
			(--[^\r]*?--\s*)+
			>
			[ \t]*
			(?=\n{2,})			// followed by a blank line
		)
		/g,hashElement);
	*/
	text = text.replace(/(\n\n[ ]{0,3}<!(--[^\r]*?--\s*)+>[ \t]*(?=\n{2,}))/g,hashElement);

	// PHP and ASP-style processor instructions (<?...?> and <%...%>)

	/*
		text = text.replace(/
		(?:
			\n\n				// Starting after a blank line
		)
		(						// save in $1
			[ ]{0,3}			// attacklab: g_tab_width - 1
			(?:
				<([?%])			// $2
				[^\r]*?
				\2>
			)
			[ \t]*
			(?=\n{2,})			// followed by a blank line
		)
		/g,hashElement);
	*/
	text = text.replace(/(?:\n\n)([ ]{0,3}(?:<([?%])[^\r]*?\2>)[ \t]*(?=\n{2,}))/g,hashElement);

	// attacklab: Undo double lines (see comment at top of this function)
	text = text.replace(/\n\n/g,"\n");
	return text;
}

var hashElement = function(wholeMatch,m1) {
	var blockText = m1;

	// Undo double lines
	blockText = blockText.replace(/\n\n/g,"\n");
	blockText = blockText.replace(/^\n/,"");
	
	// strip trailing blank lines
	blockText = blockText.replace(/\n+$/g,"");
	
	// Replace the element text with a marker ("~KxK" where x is its key)
	blockText = "\n\n~K" + (g_html_blocks.push(blockText)-1) + "K\n\n";
	
	return blockText;
};

var _RunBlockGamut = function(text) {
//
// These are all the transformations that form block-level
// tags like paragraphs, headers, and list items.
//
	text = _DoHeaders(text);

	// Do Horizontal Rules:
	var key = hashBlock("<hr />");
	text = text.replace(/^[ ]{0,2}([ ]?\*[ ]?){3,}[ \t]*$/gm,key);
	text = text.replace(/^[ ]{0,2}([ ]?\-[ ]?){3,}[ \t]*$/gm,key);
	text = text.replace(/^[ ]{0,2}([ ]?\_[ ]?){3,}[ \t]*$/gm,key);

	text = _DoLists(text);
	text = _DoCodeBlocks(text);
	text = _DoBlockQuotes(text);

	// We already ran _HashHTMLBlocks() before, in Markdown(), but that
	// was to escape raw HTML in the original Markdown source. This time,
	// we're escaping the markup we've just created, so that we don't wrap
	// <p> tags around block-level tags.
	text = _HashHTMLBlocks(text);
	text = _FormParagraphs(text);

	return text;
}


var _RunSpanGamut = function(text) {
//
// These are all the transformations that occur *within* block-level
// tags like paragraphs, headers, and list items.
//

	text = _DoCodeSpans(text);
	text = _EscapeSpecialCharsWithinTagAttributes(text);
	text = _EncodeBackslashEscapes(text);

	// Process anchor and image tags. Images must come first,
	// because ![foo][f] looks like an anchor.
	text = _DoImages(text);
	text = _DoAnchors(text);

	// Make links out of things like `<http://example.com/>`
	// Must come after _DoAnchors(), because you can use < and >
	// delimiters in inline links like [this](<url>).
	text = _DoAutoLinks(text);
	text = _EncodeAmpsAndAngles(text);
	text = _DoItalicsAndBold(text);

	// Do hard breaks:
	text = text.replace(/  +\n/g," <br />\n");

	return text;
}

var _EscapeSpecialCharsWithinTagAttributes = function(text) {
//
// Within tags -- meaning between < and > -- encode [\ ` * _] so they
// don't conflict with their use in Markdown for code, italics and strong.
//

	// Build a regex to find HTML tags and comments.  See Friedl's 
	// "Mastering Regular Expressions", 2nd Ed., pp. 200-201.
	var regex = /(<[a-z\/!$]("[^"]*"|'[^']*'|[^'">])*>|<!(--.*?--\s*)+>)/gi;

	text = text.replace(regex, function(wholeMatch) {
		var tag = wholeMatch.replace(/(.)<\/?code>(?=.)/g,"$1`");
		tag = escapeCharacters(tag,"\\`*_");
		return tag;
	});

	return text;
}

var _DoAnchors = function(text) {
//
// Turn Markdown link shortcuts into XHTML <a> tags.
//
	//
	// First, handle reference-style links: [link text] [id]
	//

	/*
		text = text.replace(/
		(							// wrap whole match in $1
			\[
			(
				(?:
					\[[^\]]*\]		// allow brackets nested one level
					|
					[^\[]			// or anything else
				)*
			)
			\]

			[ ]?					// one optional space
			(?:\n[ ]*)?				// one optional newline followed by spaces

			\[
			(.*?)					// id = $3
			\]
		)()()()()					// pad remaining backreferences
		/g,_DoAnchors_callback);
	*/
	text = text.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g,writeAnchorTag);

	//
	// Next, inline-style links: [link text](url "optional title")
	//

	/*
		text = text.replace(/
			(						// wrap whole match in $1
				\[
				(
					(?:
						\[[^\]]*\]	// allow brackets nested one level
					|
					[^\[\]]			// or anything else
				)
			)
			\]
			\(						// literal paren
			[ \t]*
			()						// no id, so leave $3 empty
			<?(.*?)>?				// href = $4
			[ \t]*
			(						// $5
				(['"])				// quote char = $6
				(.*?)				// Title = $7
				\6					// matching quote
				[ \t]*				// ignore any spaces/tabs between closing quote and )
			)?						// title is optional
			\)
		)
		/g,writeAnchorTag);
	*/
	text = text.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\]\([ \t]*()<?(.*?)>?[ \t]*((['"])(.*?)\6[ \t]*)?\))/g,writeAnchorTag);

	//
	// Last, handle reference-style shortcuts: [link text]
	// These must come last in case you've also got [link test][1]
	// or [link test](/foo)
	//

	/*
		text = text.replace(/
		(		 					// wrap whole match in $1
			\[
			([^\[\]]+)				// link text = $2; can't contain '[' or ']'
			\]
		)()()()()()					// pad rest of backreferences
		/g, writeAnchorTag);
	*/
	text = text.replace(/(\[([^\[\]]+)\])()()()()()/g, writeAnchorTag);

	return text;
}

var writeAnchorTag = function(wholeMatch,m1,m2,m3,m4,m5,m6,m7) {
	if (m7 == undefined) m7 = "";
	var whole_match = m1;
	var link_text   = m2;
	var link_id	 = m3.toLowerCase();
	var url		= m4;
	var title	= m7;
	
	if (url == "") {
		if (link_id == "") {
			// lower-case and turn embedded newlines into spaces
			link_id = link_text.toLowerCase().replace(/ ?\n/g," ");
		}
		url = "#"+link_id;
		
		if (g_urls[link_id] != undefined) {
			url = g_urls[link_id];
			if (g_titles[link_id] != undefined) {
				title = g_titles[link_id];
			}
		}
		else {
			if (whole_match.search(/\(\s*\)$/m)>-1) {
				// Special case for explicit empty url
				url = "";
			} else {
				return whole_match;
			}
		}
	}	
	
	url = escapeCharacters(url,"*_");
	var result = "<a href=\"" + url + "\"";
	
	if (title != "") {
		title = title.replace(/"/g,"&quot;");
		title = escapeCharacters(title,"*_");
		result +=  " title=\"" + title + "\"";
	}
	
	result += ">" + link_text + "</a>";
	
	return result;
}


var _DoImages = function(text) {
//
// Turn Markdown image shortcuts into <img> tags.
//

	//
	// First, handle reference-style labeled images: ![alt text][id]
	//

	/*
		text = text.replace(/
		(						// wrap whole match in $1
			!\[
			(.*?)				// alt text = $2
			\]

			[ ]?				// one optional space
			(?:\n[ ]*)?			// one optional newline followed by spaces

			\[
			(.*?)				// id = $3
			\]
		)()()()()				// pad rest of backreferences
		/g,writeImageTag);
	*/
	text = text.replace(/(!\[(.*?)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g,writeImageTag);

	//
	// Next, handle inline images:  ![alt text](url "optional title")
	// Don't forget: encode * and _

	/*
		text = text.replace(/
		(						// wrap whole match in $1
			!\[
			(.*?)				// alt text = $2
			\]
			\s?					// One optional whitespace character
			\(					// literal paren
			[ \t]*
			()					// no id, so leave $3 empty
			<?(\S+?)>?			// src url = $4
			[ \t]*
			(					// $5
				(['"])			// quote char = $6
				(.*?)			// title = $7
				\6				// matching quote
				[ \t]*
			)?					// title is optional
		\)
		)
		/g,writeImageTag);
	*/
	text = text.replace(/(!\[(.*?)\]\s?\([ \t]*()<?(\S+?)>?[ \t]*((['"])(.*?)\6[ \t]*)?\))/g,writeImageTag);

	return text;
}

var writeImageTag = function(wholeMatch,m1,m2,m3,m4,m5,m6,m7) {
	var whole_match = m1;
	var alt_text   = m2;
	var link_id	 = m3.toLowerCase();
	var url		= m4;
	var title	= m7;

	if (!title) title = "";
	
	if (url == "") {
		if (link_id == "") {
			// lower-case and turn embedded newlines into spaces
			link_id = alt_text.toLowerCase().replace(/ ?\n/g," ");
		}
		url = "#"+link_id;
		
		if (g_urls[link_id] != undefined) {
			url = g_urls[link_id];
			if (g_titles[link_id] != undefined) {
				title = g_titles[link_id];
			}
		}
		else {
			return whole_match;
		}
	}	
	
	alt_text = alt_text.replace(/"/g,"&quot;");
	url = escapeCharacters(url,"*_");
	var result = "<img src=\"" + url + "\" alt=\"" + alt_text + "\"";

	// attacklab: Markdown.pl adds empty title attributes to images.
	// Replicate this bug.

	//if (title != "") {
		title = title.replace(/"/g,"&quot;");
		title = escapeCharacters(title,"*_");
		result +=  " title=\"" + title + "\"";
	//}
	
	result += " />";
	
	return result;
}


var _DoHeaders = function(text) {

	// Setext-style headers:
	//	Header 1
	//	========
	//  
	//	Header 2
	//	--------
	//
	text = text.replace(/^(.+)[ \t]*\n=+[ \t]*\n+/gm,
		function(wholeMatch,m1){return hashBlock("<h1>" + _RunSpanGamut(m1) + "</h1>");});

	text = text.replace(/^(.+)[ \t]*\n-+[ \t]*\n+/gm,
		function(matchFound,m1){return hashBlock("<h2>" + _RunSpanGamut(m1) + "</h2>");});

	// atx-style headers:
	//  # Header 1
	//  ## Header 2
	//  ## Header 2 with closing hashes ##
	//  ...
	//  ###### Header 6
	//

	/*
		text = text.replace(/
			^(\#{1,6})				// $1 = string of #'s
			[ \t]*
			(.+?)					// $2 = Header text
			[ \t]*
			\#*						// optional closing #'s (not counted)
			\n+
		/gm, function() {...});
	*/

	text = text.replace(/^(\#{1,6})[ \t]*(.+?)[ \t]*\#*\n+/gm,
		function(wholeMatch,m1,m2) {
			var h_level = m1.length;
			return hashBlock("<h" + h_level + ">" + _RunSpanGamut(m2) + "</h" + h_level + ">");
		});

	return text;
}

// This declaration keeps Dojo compressor from outputting garbage:
var _ProcessListItems;

var _DoLists = function(text) {
//
// Form HTML ordered (numbered) and unordered (bulleted) lists.
//

	// attacklab: add sentinel to hack around khtml/safari bug:
	// http://bugs.webkit.org/show_bug.cgi?id=11231
	text += "~0";

	// Re-usable pattern to match any entirel ul or ol list:

	/*
		var whole_list = /
		(									// $1 = whole list
			(								// $2
				[ ]{0,3}					// attacklab: g_tab_width - 1
				([*+-]|\d+[.])				// $3 = first list item marker
				[ \t]+
			)
			[^\r]+?
			(								// $4
				~0							// sentinel for workaround; should be $
			|
				\n{2,}
				(?=\S)
				(?!							// Negative lookahead for another list item marker
					[ \t]*
					(?:[*+-]|\d+[.])[ \t]+
				)
			)
		)/g
	*/
	var whole_list = /^(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/gm;

	if (g_list_level) {
		text = text.replace(whole_list,function(wholeMatch,m1,m2) {
			var list = m1;
			var list_type = (m2.search(/[*+-]/g)>-1) ? "ul" : "ol";

			// Turn double returns into triple returns, so that we can make a
			// paragraph for the last item in a list, if necessary:
			list = list.replace(/\n{2,}/g,"\n\n\n");;
			var result = _ProcessListItems(list);
	
			// Trim any trailing whitespace, to put the closing `</$list_type>`
			// up on the preceding line, to get it past the current stupid
			// HTML block parser. This is a hack to work around the terrible
			// hack that is the HTML block parser.
			result = result.replace(/\s+$/,"");
			result = "<"+list_type+">" + result + "</"+list_type+">\n";
			return result;
		});
	} else {
		whole_list = /(\n\n|^\n?)(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/g;
		text = text.replace(whole_list,function(wholeMatch,m1,m2,m3) {
			var runup = m1;
			var list = m2;

			var list_type = (m3.search(/[*+-]/g)>-1) ? "ul" : "ol";
			// Turn double returns into triple returns, so that we can make a
			// paragraph for the last item in a list, if necessary:
			var list = list.replace(/\n{2,}/g,"\n\n\n");;
			var result = _ProcessListItems(list);
			result = runup + "<"+list_type+">\n" + result + "</"+list_type+">\n";	
			return result;
		});
	}

	// attacklab: strip sentinel
	text = text.replace(/~0/,"");

	return text;
}

_ProcessListItems = function(list_str) {
//
//  Process the contents of a single ordered or unordered list, splitting it
//  into individual list items.
//
	// The $g_list_level global keeps track of when we're inside a list.
	// Each time we enter a list, we increment it; when we leave a list,
	// we decrement. If it's zero, we're not in a list anymore.
	//
	// We do this because when we're not inside a list, we want to treat
	// something like this:
	//
	//    I recommend upgrading to version
	//    8. Oops, now this line is treated
	//    as a sub-list.
	//
	// As a single paragraph, despite the fact that the second line starts
	// with a digit-period-space sequence.
	//
	// Whereas when we're inside a list (or sub-list), that line will be
	// treated as the start of a sub-list. What a kludge, huh? This is
	// an aspect of Markdown's syntax that's hard to parse perfectly
	// without resorting to mind-reading. Perhaps the solution is to
	// change the syntax rules such that sub-lists must start with a
	// starting cardinal number; e.g. "1." or "a.".

	g_list_level++;

	// trim trailing blank lines:
	list_str = list_str.replace(/\n{2,}$/,"\n");

	// attacklab: add sentinel to emulate \z
	list_str += "~0";

	/*
		list_str = list_str.replace(/
			(\n)?							// leading line = $1
			(^[ \t]*)						// leading whitespace = $2
			([*+-]|\d+[.]) [ \t]+			// list marker = $3
			([^\r]+?						// list item text   = $4
			(\n{1,2}))
			(?= \n* (~0 | \2 ([*+-]|\d+[.]) [ \t]+))
		/gm, function(){...});
	*/
	list_str = list_str.replace(/(\n)?(^[ \t]*)([*+-]|\d+[.])[ \t]+([^\r]+?(\n{1,2}))(?=\n*(~0|\2([*+-]|\d+[.])[ \t]+))/gm,
		function(wholeMatch,m1,m2,m3,m4){
			var item = m4;
			var leading_line = m1;
			var leading_space = m2;

			if (leading_line || (item.search(/\n{2,}/)>-1)) {
				item = _RunBlockGamut(_Outdent(item));
			}
			else {
				// Recursion for sub-lists:
				item = _DoLists(_Outdent(item));
				item = item.replace(/\n$/,""); // chomp(item)
				item = _RunSpanGamut(item);
			}

			return  "<li>" + item + "</li>\n";
		}
	);

	// attacklab: strip sentinel
	list_str = list_str.replace(/~0/g,"");

	g_list_level--;
	return list_str;
}


var _DoCodeBlocks = function(text) {
//
//  Process Markdown `<pre><code>` blocks.
//  

	/*
		text = text.replace(text,
			/(?:\n\n|^)
			(								// $1 = the code block -- one or more lines, starting with a space/tab
				(?:
					(?:[ ]{4}|\t)			// Lines must start with a tab or a tab-width of spaces - attacklab: g_tab_width
					.*\n+
				)+
			)
			(\n*[ ]{0,3}[^ \t\n]|(?=~0))	// attacklab: g_tab_width
		/g,function(){...});
	*/

	// attacklab: sentinel workarounds for lack of \A and \Z, safari\khtml bug
	text += "~0";
	
	text = text.replace(/(?:\n\n|^)((?:(?:[ ]{4}|\t).*\n+)+)(\n*[ ]{0,3}[^ \t\n]|(?=~0))/g,
		function(wholeMatch,m1,m2) {
			var codeblock = m1;
			var nextChar = m2;
		
			codeblock = _EncodeCode( _Outdent(codeblock));
			codeblock = _Detab(codeblock);
			codeblock = codeblock.replace(/^\n+/g,""); // trim leading newlines
			codeblock = codeblock.replace(/\n+$/g,""); // trim trailing whitespace

			codeblock = "<pre><code>" + codeblock + "\n</code></pre>";

			return hashBlock(codeblock) + nextChar;
		}
	);

	// attacklab: strip sentinel
	text = text.replace(/~0/,"");

	return text;
}

var hashBlock = function(text) {
	text = text.replace(/(^\n+|\n+$)/g,"");
	return "\n\n~K" + (g_html_blocks.push(text)-1) + "K\n\n";
}


var _DoCodeSpans = function(text) {
//
//   *  Backtick quotes are used for <code></code> spans.
// 
//   *  You can use multiple backticks as the delimiters if you want to
//	 include literal backticks in the code span. So, this input:
//	 
//		 Just type ``foo `bar` baz`` at the prompt.
//	 
//	   Will translate to:
//	 
//		 <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
//	 
//	There's no arbitrary limit to the number of backticks you
//	can use as delimters. If you need three consecutive backticks
//	in your code, use four for delimiters, etc.
//
//  *  You can use spaces to get literal backticks at the edges:
//	 
//		 ... type `` `bar` `` ...
//	 
//	   Turns to:
//	 
//		 ... type <code>`bar`</code> ...
//

	/*
		text = text.replace(/
			(^|[^\\])					// Character before opening ` can't be a backslash
			(`+)						// $2 = Opening run of `
			(							// $3 = The code block
				[^\r]*?
				[^`]					// attacklab: work around lack of lookbehind
			)
			\2							// Matching closer
			(?!`)
		/gm, function(){...});
	*/

	text = text.replace(/(^|[^\\])(`+)([^\r]*?[^`])\2(?!`)/gm,
		function(wholeMatch,m1,m2,m3,m4) {
			var c = m3;
			c = c.replace(/^([ \t]*)/g,"");	// leading whitespace
			c = c.replace(/[ \t]*$/g,"");	// trailing whitespace
			c = _EncodeCode(c);
			return m1+"<code>"+c+"</code>";
		});

	return text;
}


var _EncodeCode = function(text) {
//
// Encode/escape certain characters inside Markdown code runs.
// The point is that in code, these characters are literals,
// and lose their special Markdown meanings.
//
	// Encode all ampersands; HTML entities are not
	// entities within a Markdown code span.
	text = text.replace(/&/g,"&amp;");

	// Do the angle bracket song and dance:
	text = text.replace(/</g,"&lt;");
	text = text.replace(/>/g,"&gt;");

	// Now, escape characters that are magic in Markdown:
	text = escapeCharacters(text,"\*_{}[]\\",false);

// jj the line above breaks this:
//---

//* Item

//   1. Subitem

//            special char: *
//---

	return text;
}


var _DoItalicsAndBold = function(text) {

	// <strong> must go first:
	text = text.replace(/(\*\*|__)(?=\S)([^\r]*?\S[*_]*)\1/g,
		"<strong>$2</strong>");

	text = text.replace(/(\*|_)(?=\S)([^\r]*?\S)\1/g,
		"<em>$2</em>");

	return text;
}


var _DoBlockQuotes = function(text) {

	/*
		text = text.replace(/
		(								// Wrap whole match in $1
			(
				^[ \t]*>[ \t]?			// '>' at the start of a line
				.+\n					// rest of the first line
				(.+\n)*					// subsequent consecutive lines
				\n*						// blanks
			)+
		)
		/gm, function(){...});
	*/

	text = text.replace(/((^[ \t]*>[ \t]?.+\n(.+\n)*\n*)+)/gm,
		function(wholeMatch,m1) {
			var bq = m1;

			// attacklab: hack around Konqueror 3.5.4 bug:
			// "----------bug".replace(/^-/g,"") == "bug"

			bq = bq.replace(/^[ \t]*>[ \t]?/gm,"~0");	// trim one level of quoting

			// attacklab: clean up hack
			bq = bq.replace(/~0/g,"");

			bq = bq.replace(/^[ \t]+$/gm,"");		// trim whitespace-only lines
			bq = _RunBlockGamut(bq);				// recurse
			
			bq = bq.replace(/(^|\n)/g,"$1  ");
			// These leading spaces screw with <pre> content, so we need to fix that:
			bq = bq.replace(
					/(\s*<pre>[^\r]+?<\/pre>)/gm,
				function(wholeMatch,m1) {
					var pre = m1;
					// attacklab: hack around Konqueror 3.5.4 bug:
					pre = pre.replace(/^  /mg,"~0");
					pre = pre.replace(/~0/g,"");
					return pre;
				});
			
			return hashBlock("<blockquote>\n" + bq + "\n</blockquote>");
		});
	return text;
}


var _FormParagraphs = function(text) {
//
//  Params:
//    $text - string to process with html <p> tags
//

	// Strip leading and trailing lines:
	text = text.replace(/^\n+/g,"");
	text = text.replace(/\n+$/g,"");

	var grafs = text.split(/\n{2,}/g);
	var grafsOut = new Array();

	//
	// Wrap <p> tags.
	//
	var end = grafs.length;
	for (var i=0; i<end; i++) {
		var str = grafs[i];

		// if this is an HTML marker, copy it
		if (str.search(/~K(\d+)K/g) >= 0) {
			grafsOut.push(str);
		}
		else if (str.search(/\S/) >= 0) {
			str = _RunSpanGamut(str);
			str = str.replace(/^([ \t]*)/g,"<p>");
			str += "</p>"
			grafsOut.push(str);
		}

	}

	//
	// Unhashify HTML blocks
	//
	end = grafsOut.length;
	for (var i=0; i<end; i++) {
		// if this is a marker for an html block...
		while (grafsOut[i].search(/~K(\d+)K/) >= 0) {
			var blockText = g_html_blocks[RegExp.$1];
			blockText = blockText.replace(/\$/g,"$$$$"); // Escape any dollar signs
			grafsOut[i] = grafsOut[i].replace(/~K\d+K/,blockText);
		}
	}

	return grafsOut.join("\n\n");
}


var _EncodeAmpsAndAngles = function(text) {
// Smart processing for ampersands and angle brackets that need to be encoded.
	
	// Ampersand-encoding based entirely on Nat Irons's Amputator MT plugin:
	//   http://bumppo.net/projects/amputator/
	text = text.replace(/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/g,"&amp;");
	
	// Encode naked <'s
	text = text.replace(/<(?![a-z\/?\$!])/gi,"&lt;");
	
	return text;
}


var _EncodeBackslashEscapes = function(text) {
//
//   Parameter:  String.
//   Returns:	The string, with after processing the following backslash
//			   escape sequences.
//

	// attacklab: The polite way to do this is with the new
	// escapeCharacters() function:
	//
	// 	text = escapeCharacters(text,"\\",true);
	// 	text = escapeCharacters(text,"`*_{}[]()>#+-.!",true);
	//
	// ...but we're sidestepping its use of the (slow) RegExp constructor
	// as an optimization for Firefox.  This function gets called a LOT.

	text = text.replace(/\\(\\)/g,escapeCharacters_callback);
	text = text.replace(/\\([`*_{}\[\]()>#+-.!])/g,escapeCharacters_callback);
	return text;
}


var _DoAutoLinks = function(text) {

	text = text.replace(/<((https?|ftp|dict):[^'">\s]+)>/gi,"<a href=\"$1\">$1</a>");

	// Email addresses: <address@domain.foo>

	/*
		text = text.replace(/
			<
			(?:mailto:)?
			(
				[-.\w]+
				\@
				[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
			)
			>
		/gi, _DoAutoLinks_callback());
	*/
	text = text.replace(/<(?:mailto:)?([-.\w]+\@[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+)>/gi,
		function(wholeMatch,m1) {
			return _EncodeEmailAddress( _UnescapeSpecialChars(m1) );
		}
	);

	return text;
}


var _EncodeEmailAddress = function(addr) {
//
//  Input: an email address, e.g. "foo@example.com"
//
//  Output: the email address as a mailto link, with each character
//	of the address encoded as either a decimal or hex entity, in
//	the hopes of foiling most address harvesting spam bots. E.g.:
//
//	<a href="&#x6D;&#97;&#105;&#108;&#x74;&#111;:&#102;&#111;&#111;&#64;&#101;
//	   x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;">&#102;&#111;&#111;
//	   &#64;&#101;x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;</a>
//
//  Based on a filter by Matthew Wickline, posted to the BBEdit-Talk
//  mailing list: <http://tinyurl.com/yu7ue>
//

	// attacklab: why can't javascript speak hex?
	function char2hex(ch) {
		var hexDigits = '0123456789ABCDEF';
		var dec = ch.charCodeAt(0);
		return(hexDigits.charAt(dec>>4) + hexDigits.charAt(dec&15));
	}

	var encode = [
		function(ch){return "&#"+ch.charCodeAt(0)+";";},
		function(ch){return "&#x"+char2hex(ch)+";";},
		function(ch){return ch;}
	];

	addr = "mailto:" + addr;

	addr = addr.replace(/./g, function(ch) {
		if (ch == "@") {
		   	// this *must* be encoded. I insist.
			ch = encode[Math.floor(Math.random()*2)](ch);
		} else if (ch !=":") {
			// leave ':' alone (to spot mailto: later)
			var r = Math.random();
			// roughly 10% raw, 45% hex, 45% dec
			ch =  (
					r > .9  ?	encode[2](ch)   :
					r > .45 ?	encode[1](ch)   :
								encode[0](ch)
				);
		}
		return ch;
	});

	addr = "<a href=\"" + addr + "\">" + addr + "</a>";
	addr = addr.replace(/">.+:/g,"\">"); // strip the mailto: from the visible part

	return addr;
}


var _UnescapeSpecialChars = function(text) {
//
// Swap back in all the special characters we've hidden.
//
	text = text.replace(/~E(\d+)E/g,
		function(wholeMatch,m1) {
			var charCodeToReplace = parseInt(m1);
			return String.fromCharCode(charCodeToReplace);
		}
	);
	return text;
}


var _Outdent = function(text) {
//
// Remove one level of line-leading tabs or spaces
//

	// attacklab: hack around Konqueror 3.5.4 bug:
	// "----------bug".replace(/^-/g,"") == "bug"

	text = text.replace(/^(\t|[ ]{1,4})/gm,"~0"); // attacklab: g_tab_width

	// attacklab: clean up hack
	text = text.replace(/~0/g,"")

	return text;
}

var _Detab = function(text) {
// attacklab: Detab's completely rewritten for speed.
// In perl we could fix it by anchoring the regexp with \G.
// In javascript we're less fortunate.

	// expand first n-1 tabs
	text = text.replace(/\t(?=\t)/g,"    "); // attacklab: g_tab_width

	// replace the nth with two sentinels
	text = text.replace(/\t/g,"~A~B");

	// use the sentinel to anchor our regex so it doesn't explode
	text = text.replace(/~B(.+?)~A/g,
		function(wholeMatch,m1,m2) {
			var leadingText = m1;
			var numSpaces = 4 - leadingText.length % 4;  // attacklab: g_tab_width

			// there *must* be a better way to do this:
			for (var i=0; i<numSpaces; i++) leadingText+=" ";

			return leadingText;
		}
	);

	// clean up sentinels
	text = text.replace(/~A/g,"    ");  // attacklab: g_tab_width
	text = text.replace(/~B/g,"");

	return text;
}


//
//  attacklab: Utility functions
//


var escapeCharacters = function(text, charsToEscape, afterBackslash) {
	// First we have to escape the escape characters so that
	// we can build a character class out of them
	var regexString = "([" + charsToEscape.replace(/([\[\]\\])/g,"\\$1") + "])";

	if (afterBackslash) {
		regexString = "\\\\" + regexString;
	}

	var regex = new RegExp(regexString,"g");
	text = text.replace(regex,escapeCharacters_callback);

	return text;
}


var escapeCharacters_callback = function(wholeMatch,m1) {
	var charCodeToEscape = m1.charCodeAt(0);
	return "~E"+charCodeToEscape+"E";
}

} // end of Showdown.converter


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


function md5cycle(x, k) {
var a = x[0], b = x[1], c = x[2], d = x[3];

a = ff(a, b, c, d, k[0], 7, -680876936);
d = ff(d, a, b, c, k[1], 12, -389564586);
c = ff(c, d, a, b, k[2], 17,  606105819);
b = ff(b, c, d, a, k[3], 22, -1044525330);
a = ff(a, b, c, d, k[4], 7, -176418897);
d = ff(d, a, b, c, k[5], 12,  1200080426);
c = ff(c, d, a, b, k[6], 17, -1473231341);
b = ff(b, c, d, a, k[7], 22, -45705983);
a = ff(a, b, c, d, k[8], 7,  1770035416);
d = ff(d, a, b, c, k[9], 12, -1958414417);
c = ff(c, d, a, b, k[10], 17, -42063);
b = ff(b, c, d, a, k[11], 22, -1990404162);
a = ff(a, b, c, d, k[12], 7,  1804603682);
d = ff(d, a, b, c, k[13], 12, -40341101);
c = ff(c, d, a, b, k[14], 17, -1502002290);
b = ff(b, c, d, a, k[15], 22,  1236535329);

a = gg(a, b, c, d, k[1], 5, -165796510);
d = gg(d, a, b, c, k[6], 9, -1069501632);
c = gg(c, d, a, b, k[11], 14,  643717713);
b = gg(b, c, d, a, k[0], 20, -373897302);
a = gg(a, b, c, d, k[5], 5, -701558691);
d = gg(d, a, b, c, k[10], 9,  38016083);
c = gg(c, d, a, b, k[15], 14, -660478335);
b = gg(b, c, d, a, k[4], 20, -405537848);
a = gg(a, b, c, d, k[9], 5,  568446438);
d = gg(d, a, b, c, k[14], 9, -1019803690);
c = gg(c, d, a, b, k[3], 14, -187363961);
b = gg(b, c, d, a, k[8], 20,  1163531501);
a = gg(a, b, c, d, k[13], 5, -1444681467);
d = gg(d, a, b, c, k[2], 9, -51403784);
c = gg(c, d, a, b, k[7], 14,  1735328473);
b = gg(b, c, d, a, k[12], 20, -1926607734);

a = hh(a, b, c, d, k[5], 4, -378558);
d = hh(d, a, b, c, k[8], 11, -2022574463);
c = hh(c, d, a, b, k[11], 16,  1839030562);
b = hh(b, c, d, a, k[14], 23, -35309556);
a = hh(a, b, c, d, k[1], 4, -1530992060);
d = hh(d, a, b, c, k[4], 11,  1272893353);
c = hh(c, d, a, b, k[7], 16, -155497632);
b = hh(b, c, d, a, k[10], 23, -1094730640);
a = hh(a, b, c, d, k[13], 4,  681279174);
d = hh(d, a, b, c, k[0], 11, -358537222);
c = hh(c, d, a, b, k[3], 16, -722521979);
b = hh(b, c, d, a, k[6], 23,  76029189);
a = hh(a, b, c, d, k[9], 4, -640364487);
d = hh(d, a, b, c, k[12], 11, -421815835);
c = hh(c, d, a, b, k[15], 16,  530742520);
b = hh(b, c, d, a, k[2], 23, -995338651);

a = ii(a, b, c, d, k[0], 6, -198630844);
d = ii(d, a, b, c, k[7], 10,  1126891415);
c = ii(c, d, a, b, k[14], 15, -1416354905);
b = ii(b, c, d, a, k[5], 21, -57434055);
a = ii(a, b, c, d, k[12], 6,  1700485571);
d = ii(d, a, b, c, k[3], 10, -1894986606);
c = ii(c, d, a, b, k[10], 15, -1051523);
b = ii(b, c, d, a, k[1], 21, -2054922799);
a = ii(a, b, c, d, k[8], 6,  1873313359);
d = ii(d, a, b, c, k[15], 10, -30611744);
c = ii(c, d, a, b, k[6], 15, -1560198380);
b = ii(b, c, d, a, k[13], 21,  1309151649);
a = ii(a, b, c, d, k[4], 6, -145523070);
d = ii(d, a, b, c, k[11], 10, -1120210379);
c = ii(c, d, a, b, k[2], 15,  718787259);
b = ii(b, c, d, a, k[9], 21, -343485551);

x[0] = add32(a, x[0]);
x[1] = add32(b, x[1]);
x[2] = add32(c, x[2]);
x[3] = add32(d, x[3]);

}

function cmn(q, a, b, x, s, t) {
a = add32(add32(a, q), add32(x, t));
return add32((a << s) | (a >>> (32 - s)), b);
}

function ff(a, b, c, d, x, s, t) {
return cmn((b & c) | ((~b) & d), a, b, x, s, t);
}

function gg(a, b, c, d, x, s, t) {
return cmn((b & d) | (c & (~d)), a, b, x, s, t);
}

function hh(a, b, c, d, x, s, t) {
return cmn(b ^ c ^ d, a, b, x, s, t);
}

function ii(a, b, c, d, x, s, t) {
return cmn(c ^ (b | (~d)), a, b, x, s, t);
}

function md51(s) {
txt = '';
var n = s.length,
state = [1732584193, -271733879, -1732584194, 271733878], i;
for (i=64; i<=s.length; i+=64) {
md5cycle(state, md5blk(s.substring(i-64, i)));
}
s = s.substring(i-64);
var tail = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
for (i=0; i<s.length; i++)
tail[i>>2] |= s.charCodeAt(i) << ((i%4) << 3);
tail[i>>2] |= 0x80 << ((i%4) << 3);
if (i > 55) {
md5cycle(state, tail);
for (i=0; i<16; i++) tail[i] = 0;
}
tail[14] = n*8;
md5cycle(state, tail);
return state;
}

/* there needs to be support for Unicode here,
 * unless we pretend that we can redefine the MD-5
 * algorithm for multi-byte characters (perhaps
 * by adding every four 16-bit characters and
 * shortening the sum to 32 bits). Otherwise
 * I suggest performing MD-5 as if every character
 * was two bytes--e.g., 0040 0025 = @%--but then
 * how will an ordinary MD-5 sum be matched?
 * There is no way to standardize text to something
 * like UTF-8 before transformation; speed cost is
 * utterly prohibitive. The JavaScript standard
 * itself needs to look at this: it should start
 * providing access to strings as preformed UTF-8
 * 8-bit unsigned value arrays.
 */
function md5blk(s) { /* I figured global was faster.   */
var md5blks = [], i; /* Andy King said do it this way. */
for (i=0; i<64; i+=4) {
md5blks[i>>2] = s.charCodeAt(i)
+ (s.charCodeAt(i+1) << 8)
+ (s.charCodeAt(i+2) << 16)
+ (s.charCodeAt(i+3) << 24);
}
return md5blks;
}

var hex_chr = '0123456789abcdef'.split('');

function rhex(n)
{
var s='', j=0;
for(; j<4; j++)
s += hex_chr[(n >> (j * 8 + 4)) & 0x0F]
+ hex_chr[(n >> (j * 8)) & 0x0F];
return s;
}

function hex(x) {
for (var i=0; i<x.length; i++)
x[i] = rhex(x[i]);
return x.join('');
}

function md5(s) {
return hex(md51(s));
}

/* this function is much faster,
so if possible we use it. Some IEs
are the only ones I know of that
need the idiotic second function,
generated by an if clause.  */

function add32(a, b) {
return (a + b) & 0xFFFFFFFF;
}

if (md5('hello') != '5d41402abc4b2a76b9719d911017c592') {
function add32(x, y) {
var lsw = (x & 0xFFFF) + (y & 0xFFFF),
msw = (x >> 16) + (y >> 16) + (lsw >> 16);
return (msw << 16) | (lsw & 0xFFFF);
}
}


lastVersion = JSON.parse(GM_getValue('version', '121.1437492279'));

accesskeys = JSON.parse(GM_getValue('accesskeys', '{}'));

iconsize = GM_getValue('iconsize', 'reg');

GM_setValue('version', '121.1437492279');

userData = null;

lastUpdated = 0;

mmmGetNinjaPirateVisibility = function() {
  return GM_xmlhttpRequest({
    method: 'GET',
    url: '/api/me.json',
    onload: function(npvresp1) {
      var data, url, username;
      username = JSON.parse(npvresp1.responseText).data.name;
      url = 'https://www.megamegamonitor.com/ninja_pirate_visible.php';
      data = "version=121.1437492279&username=" + username + "&accesskey=" + accesskeys[username];
      if (debugMode) {
        console.log("POST " + url + " " + data);
      }
      return GM_xmlhttpRequest({
        method: 'POST',
        url: url,
        data: data,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        onload: function(npvresp2) {
          if (debugMode) {
            console.log(npvresp2.responseText);
          }
          if (npvresp2.responseText === '0') {
            $('.mmm-ninja-pirate-status').html('You are currently <strong>hidden</strong> from the enemy (you are still visible to your friends). This is the default. <a href="#" class="mmm-change-ninja-pirate-visibility" data-change-to="1">Come out of hiding?</a>');
          } else if (npvresp2.responseText === '1') {
            $('.mmm-ninja-pirate-status').html('You are currently <strong>visible</strong> to the enemy. <a href="#" class="mmm-change-ninja-pirate-visibility" data-change-to="0">Go back into hiding?</a>');
          } else {
            $('.mmm-ninja-pirate-status').text(npvresp2.responseText);
          }
          return $('.mmm-change-ninja-pirate-visibility').click(function() {
            return mmmChangeNinjaPirateVisibility($(this).data('change-to'));
          });
        }
      });
    }
  });
};

mmmChangeNinjaPirateVisibility = function(visible) {
  return GM_xmlhttpRequest({
    method: 'GET',
    url: '/api/me.json',
    onload: function(npvresp1) {
      var data, url, username;
      username = JSON.parse(npvresp1.responseText).data.name;
      url = 'https://www.megamegamonitor.com/ninja_pirate_visible.php';
      data = "version=121.1437492279&username=" + username + "&accesskey=" + accesskeys[username] + "&v=" + (visible != null ? visible : {
        1: 0
      });
      if (debugMode) {
        console.log("POST " + url + " " + data);
      }
      return GM_xmlhttpRequest({
        method: 'POST',
        url: url,
        data: data,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        onload: function(npvresp2) {
          if (debugMode) {
            console.log('MegaMegaMonitor Debug: mmmChangeNinjaPirateVisibility() - response received');
          }
          mmmGetNinjaPirateVisibility();
          return alert(npvresp2.responseText);
        }
      });
    }
  });
};

mmmOptions = function() {
  var highest_megalounge_chain_name, highest_megalounge_chain_number, highest_megalounge_spriteset_position, i_am_a_ninja, i_am_a_pirate, sub_encryption_select_box;
  history.pushState({}, "MegaMegaMonitor Options/Tools", "/r/MegaMegaMonitor/wiki/options");
  window.onpopstate = function() {
    if (window.location.pathname === "/r/MegaMegaMonitor/wiki/options") {
      return window.history.back();
    } else {
      return window.location.reload();
    }
  };
  $('link[rel="stylesheet"], style:not(#mmm-css-block)').remove();
  $('head').append('<link href="//d1wjam29zgrnhb.cloudfront.net/css/combined2.css" rel="stylesheet">');
  $('body').html('<div class=\"container\" id=\"mmm-options\"> <h1>MegaMegaMonitor Options/Tools</h1> <a href=\"#back-to-reddit\" class=\"btn btn-lg btn-primary pull-right\">Back to Reddit</a> <p> For MegaMegaMonitor help, see <a href=\"/r/MegaMegaMonitor\">/r/MegaMegaMonitor</a>. </p> <hr/> <h2>Options</h2> <div class=\"row\"> <div class=\"col-md-4\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Suppress icons</div> <div class=\"panel-body\"> <p> If you\'re part of a private subreddit that you don\'t care about, you can hide that subreddit\'s icon so that it won\'t appear alongside the names of your fellow members. Check the checkboxes for the subs you want to <em>hide</em> the icons for: </p> <ul id=\"mmm-options-hidden-subs\"></ul> </div> </div> </div> <div class=\"col-md-4\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Icon size</div> <div class=\"panel-body\"> <p> Some people prefer smaller icons alongside the names of their friends. </p> <select class=\"form-control\" id=\"mmm-iconsize\"> <option value=\"reg\">Regular (default)</option> <option value=\"tiny\">Tiny</option> </select> </div> </div> </div> <div class=\"col-md-4 mmm-ninja-only\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Ninja stealth</div> <div class=\"panel-body\"> <p> As a member of <a href=\"/r/NinjaLounge\">/r/NinjaLounge</a>, you may opt to take off your disguise and let the filthy pirates see your identity. Changes here can take up to 24 hours to take effect. </p> <p class=\"mmm-ninja-pirate-status\"></p> </div> </div> </div> <div class=\"col-md-4 mmm-pirate-only\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Pirate magic</div> <div class=\"panel-body\"> <p> As a member of <a href=\"/r/PirateLounge\">/r/PirateLounge</a>, you may opt to come out into the open and let the cowardly ninjas see your identity. Changes here can take up to 24 hours to take effect. </p> <p class=\"mmm-ninja-pirate-status\"></p> </div> </div> </div> </div> <div class=\"mmm-debugMode-only\"> <hr/> <h2>Debugging</h2> <p> These tools only work for MegaMegaMonitor developers. Sure, you were clever enough to find them, but I promise you that they don\'t <em>do</em> anything. </p> <input type=\"text\" class=\"form-control\" placeholder=\"Command?\"/> <button id=\"mmm-debug\" class=\"btn btn-default\">Debug</button> <div id=\"mmm-debug-status\"></div> </div> <hr/> <h2>Tools</h2> <div class=\"row\"> <div class=\"col-md-6\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Find user\'s post in sub</div> <div class=\"panel-body\"> <p> Looking to gild someone in their \"highest\" MegaLounge? Or just trying to find a comment somebody made, once? This tool will help (but it\'s super slow!). </p> <div class=\"form-horizontal\"> <div class=\"form-group\"> <label for=\"mmm-tools-find-comment-username\" class=\"col-sm-3 control-label\">Username:</label> <div class=\"col-sm-9\"> <input class=\"form-control\" type=\"text\" id=\"mmm-tools-find-comment-username\" placeholder=\"e.g. avapoet\"/> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-find-comment-subreddit\" class=\"col-sm-3 control-label\">Subreddit:</label> <div class=\"col-sm-9\"> <input class=\"form-control\" type=\"text\" id=\"mmm-tools-find-comment-subreddit\" placeholder=\"e.g. MegaMegaMonitor\"/> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-find-comment-subreddit\" class=\"col-sm-3 control-label\">Find:</label> <div class=\"col-sm-9\"> <select class=\"form-control\" id=\"mmm-tools-find-comment-type\"> <option value=\"\">Any</option> <option value=\"submitted\">Post</option> <option value=\"comments\">Comment</option> </select> </div> </div> <div class=\"form-group\"> <div class=\"col-sm-offset-3 col-sm-9\"> <button id=\"mmm-tools-find-comment-submit\" class=\"btn btn-lg btn-default\">Search</button> </div> </div> </div> </div> </div> </div> <div class=\"col-md-6\"> <div class=\"panel panel-info\"> <div class=\"panel-heading\">Graph my gilding patterns</div> <div class=\"panel-body\"> <p> Generate graphs showing where, what, and who you gild (and optionally come share your results in <a href=\"/r/MegaMegaMonitor/\">/r/MegaMegaMonitor/</a>)! This works by going through <a href=\"/u/me/gilded/given\">your entire gilding history</a>, but for some super-gilders it might only go back so-far (owing to Reddit limitations). </p> <p> <button id=\"mmm-tools-gilding-graphs-submit\" class=\"btn btn-lg btn-default\">Generate</button> </p> </div> </div> </div> </div> <div class=\"row\"> <div class=\"col-md-12\"> <div class=\"panel panel-warning\"> <div class=\"panel-heading\">Secret messages</div> <div class=\"panel-body\"> <p> It\'s possible to write secret messages in posts and comments that can only be seen by fellow MegaMegaMonitor users, so long as they\'ve been granted access to specific subreddits. So you could, for example, post a comment in <a href=\"/r/trees\">/r/trees</a> but with some content that can only be read by <a href=\"/r/gildedtrees\">/r/gildedtrees</a> members. </p> <div class=\"form-group\"> <label for=\"mmm-tools-encrypt-sub\">Subreddit:</label> <select class=\"form-control\" id=\"mmm-tools-encrypt-sub\"></select> <span class=\"help-block\"> Readers must be part of which subreddit in order to decrypt your message? </span> </div> <div class=\"form-group\"> <label for=\"mmm-tools-encrypt-public\">Public message:</label> <input class=\"form-control\" type=\"text\" id=\"mmm-tools-encrypt-public\"/> <span class=\"help-block\"> Optionally provide a message that\'s shown to people who either don\'t have MegaMegaMonitor or else don\'t have access to the appropriate subreddit. This text - if you provide any - will be a hyperlink to <a href=\"/r/MegaMegaMonitor/wiki/encrypted\">/r/MegaMegaMonitor/wiki/encrypted</a>, which explains that they need to install MegaMegaMonitor to see the secret message. If in doubt, leave this blank. </span> </div> <div class=\"form-group\"> <label for=\"mmm-tools-encrypt-secret\">Secret message:</label> <textarea class=\"form-control\" type=\"text\" id=\"mmm-tools-encrypt-secret\" rows=\"4\"></textarea> <span class=\"help-block\"> Your secret message. You can include Reddit-style markdown to add links, bold, italic, etc. You can even add code that\'s specific to the sub you\'re posting in, such as spoiler tags or ponymotes. Try to keep it short (fewer than about 150 words) or you might run into problems. Note that /r/... subreddit names will *not* automatically get turned into hyperlinks. </span> </div> <div class=\"form-group\"> <button id=\"mmm-tools-encrypt-submit\" class=\"btn btn-lg btn-default\">Encrypt</button> </div> <div class=\"form-group\"> <label for=\"mmm-tools-encrypt-output\">Copy-paste this into your post/comment:</label> <textarea class=\"form-control\" type=\"text\" id=\"mmm-tools-encrypt-output\" rows=\"4\"></textarea> <span class=\"help-block\"> Copy-paste the code above into your post or comment, and submit as normal. If the code is too long for a Reddit post/comment, shorten your secret message and try again. If your message gets rejected by Reddit\'s spam filter, make sure you put some non-encrypted content into your message, too. </span> </div> </div> </div> </div> </div> <h3>List Maker</h3> <p> A tool to help you make and manipulate lists of users. Useful for moderators! See <a href=\"/r/MegaMegaMonitor/wiki/lists\">/r/MegaMegaMonitor/wiki/lists</a> for examples of use and \'recipes\' representing the entry criteria for a variety of different private subreddits. </p> <div class=\"row\"> <div class=\"col-md-4 mmm-list\"> <div class=\"panel panel-danger\"> <div class=\"panel-heading\">List 1 (finding people)</div> <div class=\"panel-body\"> <div class=\"form-horizontal\"> <div class=\"form-group\"> <label for=\"mmm-tools-list-1-find\" class=\"col-sm-3 control-label\">Find:</label> <div class=\"col-sm-9\"> <select class=\"form-control mmm-tools-list-find\" id=\"mmm-tools-list-1-find\"> <option value=\"everybody\">Everybody</option> <option value=\"gildees\">Gildees</option> <option value=\"3gildees\">Triple-gildees</option> </select> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-1-sub\" class=\"col-sm-3 control-label\">Sub:</label> <div class=\"col-sm-9\"> <input class=\"form-control mmm-tools-list-sub\" type=\"text\" id=\"mmm-tools-list-1-sub\" placeholder=\"lounge\"/> <span class=\"help-block\"> Specify multiple subs by separating with a plus sign (+). And go put the kettle on; it\'ll take a while. </span> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-1-limit\" class=\"col-sm-3 control-label\">Limit:</label> <div class=\"col-sm-9\"> <input class=\"form-control mmm-tools-list-limit\" type=\"number\" id=\"mmm-tools-list-1-limit\" min=\"1\"/> <span class=\"help-block\"> Optionally limit the number of results to be to make the list generate faster. </span> </div> </div> <div class=\"form-group\"> <div class=\"col-sm-offset-3 col-sm-9\"> <button class=\"btn btn-default form-control mmm-tools-list-submit\" id=\"mmm-tools-list-1-submit\">Start</button> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-1-output\" class=\"col-sm-3 control-label\">List:</label> <div class=\"col-sm-9\"> <textarea class=\"form-control mmm-tools-list-output\" id=\"mmm-tools-list-1-output\" rows=\"8\"/> </div> </div> <div class=\"form-group\"> <div class=\"col-sm-12\"> <button class=\"btn btn-default form-control mmm-tools-list-clear\">Clear</button> </div> </div> </div> </div> </div> </div> <div class=\"col-md-4 mmm-list\"> <div class=\"panel panel-danger\"> <div class=\"panel-heading\">List 2 (filtering)</div> <div class=\"panel-body\"> <div class=\"form-horizontal\"> <div class=\"form-group\"> <div class=\"col-sm-12 btn-group-vertical\"> <button class=\"btn btn-default form-control\" id=\"mmm-tools-list-copy-1-2\">Copy FROM List 1</button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-list-copy-2-1\">Copy TO List 1</button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-list-copy-3-2\">Copy FROM List 3</button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-list-copy-2-3\">Copy TO List 3</button> <button class=\"btn btn-default form-control mmm-tools-list-clear\">Clear</button> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-2-output\" class=\"col-sm-3 control-label\">List:</label> <div class=\"col-sm-9\"> <textarea class=\"form-control mmm-tools-list-output\" id=\"mmm-tools-list-2-output\" rows=\"8\"/> </div> </div> <div class=\"form-group\"> <label class=\"col-sm-12\">Filter to List 3:</label> <div class=\"col-sm-12 btn-group-vertical\"> <button class=\"btn btn-default form-control\" id=\"mmm-tools-filter-1-minus-2\"> <span class=\"mmm-venn-icon mmm-venn-icon-1minus2\"/> List 1 minus List 2 </button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-filter-2-minus-1\"> <span class=\"mmm-venn-icon mmm-venn-icon-2minus1\"/> List 2 minus List 1 </button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-filter-intersection\"> <span class=\"mmm-venn-icon mmm-venn-icon-intersection\"/> Intersection of 1 and 2 </button> <button class=\"btn btn-default form-control\" id=\"mmm-tools-filter-1-plus-2\"> <span class=\"mmm-venn-icon mmm-venn-icon-1plus2\"/> List 1 plus List 2 </button> </div> </div> </div> </div> </div> </div> <div class=\"col-md-4 mmm-list\"> <div class=\"panel panel-danger\"> <div class=\"panel-heading\">List 3 (operations)</div> <div class=\"panel-body\"> <div class=\"form-horizontal\"> <div class=\"form-group\"> <div class=\"col-sm-12\"> <button class=\"btn btn-default form-control mmm-tools-list-clear\">Clear</button> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-3-output\" class=\"col-sm-3 control-label\">List:</label> <div class=\"col-sm-9\"> <textarea class=\"form-control mmm-tools-list-output\" id=\"mmm-tools-list-3-output\" rows=\"8\"/> </div> </div> <div class=\"form-group\"> <label class=\"col-sm-12\">With List 3:</label> <div class=\"col-sm-12 btn-group-vertical\"> <button class=\"btn btn-default form-control\" id=\"mmm-tools-invite\">Invite to subreddit...</button> </div> </div> <div class=\"form-group\"> <label for=\"mmm-tools-list-3-log\" class=\"col-sm-3 control-label\">Log:</label> <div class=\"col-sm-9\"> <textarea class=\"form-control mmm-tools-list-log\" id=\"mmm-tools-list-3-log\" rows=\"8\"/> </div> </div> </div> </div> </div> </div> </div> </div>');
  $('a[href="#back-to-reddit"]').click(function() {
    window.history.back();
    return false;
  });
  $('#mmm-iconsize').val(iconsize).on('change click keyup', function() {
    iconsize = $('#mmm-iconsize').val();
    return GM_setValue('iconsize', iconsize);
  });
  i_am_a_pirate = false;
  i_am_a_ninja = false;
  $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-mmm\" data-id=\"mmm\"> <label for=\"mmm-options-hidden-subs-mmm\"><span class=\"mmm-icon mmm-icon-64\"></span> MegaMegaMonitor users</label></li>");
  highest_megalounge_chain_number = -1;
  highest_megalounge_chain_name = '';
  highest_megalounge_spriteset_position = -1;
  userData.mySubreddits.forEach(function(sub) {
    if (debugMode) {
      console.log("MegaMegaMonitor Debug: enumerating " + sub.display_name);
    }
    if (sub.display_name === 'NinjaLounge') {
      i_am_a_ninja = true;
    }
    if (sub.display_name === 'PirateLounge') {
      i_am_a_pirate = true;
    }
    if (sub.chain_number) {
      if (sub.chain_number > highest_megalounge_chain_number) {
        highest_megalounge_chain_number = sub.chain_number;
        highest_megalounge_chain_name = sub.display_name;
        return highest_megalounge_spriteset_position = sub.spriteset_position;
      }
    } else {
      return $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-" + sub.id + "\" data-id=\"" + sub.id + "\"> <label for=\"mmm-options-hidden-subs-" + sub.id + "\"><span class=\"mmm-icon mmm-icon-" + sub.spriteset_position + "\"></span> " + sub.display_name + "</label></li>");
    }
  });
  if (highest_megalounge_chain_number > -1) {
    $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-chain\" data-id=\"chain\"> <label for=\"mmm-options-hidden-subs-chain\"><span class=\"mmm-icon mmm-icon-" + highest_megalounge_spriteset_position + "\"></span> MegaLounge chain</label></li>");
  }
  suppressionList.forEach(function(id) {
    return $("#mmm-options-hidden-subs-" + id).prop('checked', true);
  });
  $('#mmm-options-hidden-subs input:checkbox').on('click', function() {
    var suppressionList;
    suppressionList = $('#mmm-options-hidden-subs input:checkbox:checked').map(function() {
      return $(this).data('id');
    }).toArray();
    if (debugMode) {
      console.log("MegaMegaMonitor Debug: writing suppressionList = " + (JSON.stringify(suppressionList)));
    }
    return GM_setValue('suppressionList', JSON.stringify(suppressionList));
  });
  if (i_am_a_ninja) {
    $('#mmm-options').addClass('mmm-i-am-a-ninja');
  }
  if (i_am_a_pirate) {
    $('#mmm-options').addClass('mmm-i-am-a-pirate');
  }
  if (i_am_a_ninja || i_am_a_pirate) {
    mmmGetNinjaPirateVisibility();
  }
  $('#mmm-tools-find-comment-submit').click(function() {
    window.mmm_tools_find_comment_username = $('#mmm-tools-find-comment-username').val();
    window.mmm_tools_find_comment_subreddit = $('#mmm-tools-find-comment-subreddit').val().toLowerCase();
    window.mmm_tools_find_comment_type = $('#mmm-tools-find-comment-type').val();
    window.mmm_tools_find_comment_after = '';
    window.mmm_tools_find_comment_scanned = 0;
    window.mmm_tools_find_comment_cancel = false;
    $('body').html('<div class=\"container\" id=\"mmm-options\"> <h1>MegaMegaMonitor Options/Tools</h1> <a href=\"#back-to-reddit\" class=\"btn btn-lg btn-primary pull-right\">Back to Reddit</a> <h2>Searching...</h2> <p> <a href=\"#\" id=\"mmm-search-cancel\">Stop searching</a>. <a href=\"#back-to-reddit\">Back to Reddit</a>. </p> <p id=\"mmm-search-progress\"> 0 possibilities scanned. </p> <ul id=\"mmm-search-results\"></ul> </div>');
    $('a[href="#back-to-reddit"]').click(function() {
      window.location.reload();
      return false;
    });
    $('#mmm-search-cancel').click(function() {
      window.mmm_tools_find_comment_cancel = true;
      return false;
    });
    mmmToolsFind();
    return false;
  });
  $('#mmm-tools-gilding-graphs-submit').on('click', function() {
    var mmm_gg_l, my_gildings_given_json;
    my_gildings_given_json = [];
    mmm_gg_l = function(mmm_gg_n, mmm_gg_i) {
      var mmm_gg_t;
      mmm_gg_t = '/u/' + mmm_gg_n + '/gilded/given.json?limit=100&after=' + mmm_gg_i;
      $('#mmm_gg_d').append('.');
      return $.getJSON(mmm_gg_t, function(mmm_gg_i) {
        my_gildings_given_json.push(mmm_gg_i.data.children);
        if (null !== mmm_gg_i.data.after) {
          return setTimeout(function() {
            return mmm_gg_l(mmm_gg_n, mmm_gg_i.data.after);
          }, 2000);
        } else {
          mmm_gg_t = [];
          while (my_gildings_given_json.length > 0) {
            mmm_gg_t = mmm_gg_t.concat(my_gildings_given_json.shift());
          }
          mmm_gg_t = JSON.stringify(mmm_gg_t.map(function(mmm_gg_n) {
            return {
              kind: mmm_gg_n.kind,
              subreddit: mmm_gg_n.data.subreddit,
              author: mmm_gg_n.data.author
            };
          }));
          $('body > .container:first').html('<h1>Almost done...</h1><p>Just drawing some graphs...</p><form method="post" action="https://www.megamegamonitor.com/gilding-graph/"><input type="hidden" name="version" value="121.1437492279" /><input type="hidden" name="u" /><input type="hidden" name="g" /></form>');
          $('input[name="u"]').val(mmm_gg_n);
          $('input[name="g"]').val(mmm_gg_t);
          return $('form').submit();
        }
      });
    };
    $('body > .container:first').html('<h1>Please wait<span id="mmm_gg_d"></span></h1><p>This will take a little over 2 seconds per 100 gildings you\'ve given. If it freezes for a long time (no dots appearing), Reddit probably went down again. :-(</p>');
    $.get('/api/me.json', function(mmm_gg_n) {
      return mmm_gg_l(mmm_gg_n.data.name, '');
    });
    return false;
  });
  sub_encryption_select_box = $('#mmm-tools-encrypt-sub');
  userData.mySubreddits.forEach(function(cryptosub) {
    var latest_crypto_key;
    latest_crypto_key = cryptosub.cryptos[cryptosub.cryptos.length - 1];
    return sub_encryption_select_box.append("<option value=\"" + latest_crypto_key[1] + "\" data-crypto-id=\"" + latest_crypto_key[0] + "\" data-sub-id=\"" + cryptosub.id + "\">" + cryptosub.display_name + "</option>");
  });
  $('#mmm-tools-encrypt-submit').on('click', function() {
    var encrypt_ciphertext, encrypt_crypto_id, encrypt_key, encrypt_plaintext;
    encrypt_plaintext = $('#mmm-tools-encrypt-secret').val();
    encrypt_key = $('#mmm-tools-encrypt-sub').val();
    encrypt_crypto_id = $('#mmm-tools-encrypt-sub option:selected').data('crypto-id');
    encrypt_ciphertext = CryptoJS.AES.encrypt(encrypt_plaintext, encrypt_key).toString();
    return $('#mmm-tools-encrypt-output').val("[" + ($('#mmm-tools-encrypt-public').val()) + "](/r/MegaMegaMonitor/wiki/encrypted \"" + encrypt_crypto_id + ":" + encrypt_ciphertext + "\")");
  });
  $('.mmm-tools-list-submit').on('click', function() {
    var list_find, list_sub, mmmListProcessor, wrapper;
    $(this).prop('disabled', true).text('Please wait |');
    wrapper = $(this).closest('.mmm-list');
    list_find = wrapper.find('.mmm-tools-list-find').val();
    list_sub = wrapper.find('.mmm-tools-list-sub').val();
    window.mmm_list_limit = wrapper.find('.mmm-tools-list-limit').val();
    if (window.mmm_list_limit === '') {
      window.mmm_list_limit = 999999999999999999999999;
    }
    window.mmm_list_output_area = wrapper.find('.mmm-tools-list-output');
    window.mmm_list_output_area.text('');
    window.mmm_list_submit_button = wrapper.find('.mmm-tools-list-submit');
    window.mmm_list_finds = 0;
    window.mmm_list_pages = 0;
    window.mmm_list_after = '';
    window.mmm_list_results = [];
    if (list_find === 'everybody') {
      window.mmm_list_url = "/r/" + list_sub + "/about/contributors.json";
      mmmListProcessor = function() {
        return $.getJSON(window.mmm_list_url + "?limit=100&after=" + window.mmm_list_after, function(json) {
          window.mmm_list_pages++;
          window.mmm_list_after = json.data.after;
          json.data.children.forEach(function(child) {
            if (child.name !== '[deleted]') {
              window.mmm_list_finds++;
              return window.mmm_list_results.push(child.name);
            }
          });
          if ((json.data.after !== null) && (window.mmm_list_finds < window.mmm_list_limit)) {
            window.mmm_list_submit_button.text("Please wait " + ['|', '/', '-', '\\'][window.mmm_list_pages % 4] + " (" + window.mmm_list_pages + "|" + window.mmm_list_finds + ")");
            setTimeout(mmmListProcessor, 2000);
          } else {
            window.mmm_list_submit_button.text('Done!');
            setTimeout(function() {
              return window.mmm_list_submit_button.prop('disabled', false).text('Start');
            }, 5000);
          }
          return window.mmm_list_output_area.val(window.mmm_list_results.join("\n"));
        });
      };
      mmmListProcessor();
    }
    if (list_find === '3gildees') {
      window.mmm_list_url = "/r/" + list_sub + "/gilded.json";
      mmmListProcessor = function() {
        console.log(window.mmm_list_url + "?limit=100&after=" + window.mmm_list_after);
        return $.getJSON(window.mmm_list_url + "?limit=100&after=" + window.mmm_list_after, function(json) {
          var mmm_list_output_area_triple_gilds;
          window.mmm_list_pages++;
          window.mmm_list_after = json.data.after;
          json.data.children.forEach(function(child) {
            var found_existing_mmm_gildee, mmm_search_new_gildee_name;
            mmm_search_new_gildee_name = child.data.author;
            if (mmm_search_new_gildee_name !== '[deleted]') {
              found_existing_mmm_gildee = false;
              window.mmm_list_results.forEach(function(existing_mmm_gildee) {
                if (existing_mmm_gildee[0] === mmm_search_new_gildee_name) {
                  found_existing_mmm_gildee = true;
                  console.log("Incrementing " + mmm_search_new_gildee_name + " by " + child.data.gilded);
                  return existing_mmm_gildee[1] += child.data.gilded;
                }
              });
              if (!found_existing_mmm_gildee) {
                console.log("Found " + mmm_search_new_gildee_name + " (" + child.data.gilded + ")");
                return window.mmm_list_results.push([mmm_search_new_gildee_name, child.data.gilded]);
              }
            }
          });
          window.mmm_list_finds = 0;
          mmm_list_output_area_triple_gilds = [];
          window.mmm_list_results.forEach(function(mmm_found_gildee_and_count) {
            if (mmm_found_gildee_and_count[1] >= 3) {
              console.log(mmm_found_gildee_and_count[0] + " is a triple-gildee");
              window.mmm_list_finds++;
              return mmm_list_output_area_triple_gilds.push(mmm_found_gildee_and_count[0]);
            }
          });
          window.mmm_list_output_area.val(mmm_list_output_area_triple_gilds.join("\n"));
          if ((json.data.after !== null) && (window.mmm_list_finds < window.mmm_list_limit)) {
            window.mmm_list_submit_button.text("Please wait " + ['|', '/', '-', '\\'][window.mmm_list_pages % 4] + " (" + window.mmm_list_pages + "|" + window.mmm_list_finds + ")");
            return setTimeout(mmmListProcessor, 2000);
          } else {
            window.mmm_list_submit_button.text('Done!');
            return setTimeout(function() {
              return window.mmm_list_submit_button.prop('disabled', false).text('Start');
            }, 5000);
          }
        });
      };
      mmmListProcessor();
    }
    if (list_find === 'gildees') {
      window.mmm_list_url = "/r/" + list_sub + "/gilded.json";
      mmmListProcessor = function() {
        return $.getJSON(window.mmm_list_url + "?limit=100&after=" + window.mmm_list_after, function(json) {
          window.mmm_list_pages++;
          window.mmm_list_after = json.data.after;
          json.data.children.forEach(function(child) {
            var mmm_search_new_gildee_name;
            mmm_search_new_gildee_name = child.data.author;
            if ((mmm_search_new_gildee_name !== '[deleted]') && (window.mmm_list_results.indexOf(mmm_search_new_gildee_name) === -1)) {
              window.mmm_list_finds++;
              return window.mmm_list_results.push(mmm_search_new_gildee_name);
            }
          });
          if ((json.data.after !== null) && (window.mmm_list_finds < window.mmm_list_limit)) {
            window.mmm_list_submit_button.text("Please wait " + ['|', '/', '-', '\\'][window.mmm_list_pages % 4] + " (" + window.mmm_list_pages + "|" + window.mmm_list_finds + ")");
            setTimeout(mmmListProcessor, 2000);
          } else {
            window.mmm_list_submit_button.text('Done!');
            setTimeout(function() {
              return window.mmm_list_submit_button.prop('disabled', false).text('Start');
            }, 5000);
          }
          return window.mmm_list_output_area.val(window.mmm_list_results.join("\n"));
        });
      };
      return mmmListProcessor();
    }
  });
  $('.mmm-tools-list-clear').on('click', function() {
    return $(this).closest('.mmm-list').find('.mmm-tools-list-output').val('');
  });
  $('#mmm-tools-list-copy-1-2').on('click', function() {
    return $('#mmm-tools-list-2-output').val($('#mmm-tools-list-1-output').val());
  });
  $('#mmm-tools-list-copy-2-1').on('click', function() {
    return $('#mmm-tools-list-1-output').val($('#mmm-tools-list-2-output').val());
  });
  $('#mmm-tools-list-copy-3-2').on('click', function() {
    return $('#mmm-tools-list-2-output').val($('#mmm-tools-list-3-output').val());
  });
  $('#mmm-tools-list-copy-2-3').on('click', function() {
    return $('#mmm-tools-list-3-output').val($('#mmm-tools-list-2-output').val());
  });
  $('#mmm-tools-filter-1-minus-2').on('click', function() {
    var list1, list2;
    list1 = $('#mmm-tools-list-1-output').val().split("\n");
    list2 = $('#mmm-tools-list-2-output').val().split("\n");
    return $('#mmm-tools-list-3-output').val(list1.filter(function(n) {
      return list2.indexOf(n) === -1;
    }).join("\n"));
  });
  $('#mmm-tools-filter-2-minus-1').on('click', function() {
    var list1, list2;
    list1 = $('#mmm-tools-list-1-output').val().split("\n");
    list2 = $('#mmm-tools-list-2-output').val().split("\n");
    return $('#mmm-tools-list-3-output').val(list2.filter(function(n) {
      return list1.indexOf(n) === -1;
    }).join("\n"));
  });
  $('#mmm-tools-filter-intersection').on('click', function() {
    var list1, list2;
    list1 = $('#mmm-tools-list-1-output').val().split("\n");
    list2 = $('#mmm-tools-list-2-output').val().split("\n");
    return $('#mmm-tools-list-3-output').val(list1.filter(function(n) {
      return list2.indexOf(n) !== -1;
    }).join("\n"));
  });
  $('#mmm-tools-filter-1-plus-2').on('click', function() {
    var list1, list2;
    list1 = $('#mmm-tools-list-1-output').val().split("\n");
    list2 = $('#mmm-tools-list-2-output').val().split("\n");
    return $('#mmm-tools-list-3-output').val(list1.join("\n") + "\n" + list2.filter(function(n) {
      return list1.indexOf(n) === -1;
    }).join("\n"));
  });
  $('#mmm-tools-invite').on('click', function() {
    window.mmm_invite_to = prompt('Invite List 3 to which subreddit?');
    if (window.mmm_invite_to && window.mmm_invite_to.length > 0) {
      $('#mmm-tools-invite').data('old-text', $('#mmm-tools-invite').text()).text('Warming up...').prop('disabled', true);
      $('#mmm-tools-list-3-log').text("With /r/" + window.mmm_invite_to + ":");
      return $.get('/api/me.json', function(mejson) {
        window.modhash = mejson.data.modhash;
        $('#mmm-tools-invite').text('Waiting...');
        return setTimeout(mmmInvite, 2000);
      });
    }
  });
  return false;
};

mmmInvite = function() {
  var list3_invite_now, list3_invitees;
  list3_invitees = $('#mmm-tools-list-3-output').val().split("\n");
  list3_invite_now = $.trim(list3_invitees.shift());
  if (list3_invite_now !== '') {
    $('#mmm-tools-invite').text("Inviting " + list3_invite_now + "...");
    return $.post("/r/" + window.mmm_invite_to + "/api/friend", {
      api_type: 'json',
      type: 'contributor',
      name: list3_invite_now,
      uh: window.modhash
    }, function(data) {
      if (data.json.errors && data.json.errors.length > 0) {
        if (data.json.errors[0][0] === 'USER_DOESNT_EXIST') {
          $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"));
          $('#mmm-tools-list-3-log').append("\nFailed to invite " + list3_invite_now + ": user doesn't exist!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
          if (list3_invitees.length > 0) {
            $('#mmm-tools-invite').text('Waiting...');
            setTimeout(mmmInvite, 2000);
          } else {
            $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
            $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false);
          }
        }
        if (data.json.errors[0][0] === 'BANNED_FROM_SUBREDDIT') {
          $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"));
          $('#mmm-tools-list-3-log').append("\nFailed to invite " + list3_invite_now + ": user banned from sub!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
          if (list3_invitees.length > 0) {
            $('#mmm-tools-invite').text('Waiting...');
            return setTimeout(mmmInvite, 2000);
          } else {
            $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
            return $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false);
          }
        } else {
          $('#mmm-tools-list-3-log').append("\nFailed to invite " + list3_invite_now + ": " + data.json.errors[0][0] + "\nSTOPPING HERE!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
          return $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false);
        }
      } else {
        $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"));
        $('#mmm-tools-list-3-log').append("\nInvited " + list3_invite_now).scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
        if (list3_invitees.length > 0) {
          $('#mmm-tools-invite').text('Waiting...');
          return setTimeout(mmmInvite, 2000);
        } else {
          $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight);
          return $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false);
        }
      }
    });
  } else {
    $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"));
    return mmmInvite();
  }
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
            $('#mmm-search-results').append("<li><a href=\"/" + (child.data.link_id.substr(3)) + "#" + child.data.id + "\">Comment on " + child.data.link_title + "</a> (" + created_at_friendly + ")</li>");
          } else {
            $('#mmm-search-results').append("<li><a href=\"" + child.data.permalink + "\">" + child.data.title + "</a> (" + created_at_friendly + ")</li>");
          }
        }
      });
      $('#mmm-search-progress').text(window.mmm_tools_find_comment_scanned + " possibilities scanned. " + ($('#mmm-search-results li').length) + " results found.");
      if (json.data.after === null) {
        window.mmm_tools_find_comment_cancel = true;
      } else {
        setTimeout(mmmToolsFind, 2000);
      }
    }
  });
};

proveIdentity = function(username, proof_required) {
  var url;
  if (debugMode) {
    console.log("MegaMegaMonitor Debug: proof of identity requested - " + proof_required);
  }
  url = "/r/" + proof_required + "/about.json";
  if (debugMode) {
    console.log("GET " + url);
  }
  return GM_xmlhttpRequest({
    method: 'GET',
    url: url,
    onload: function(pr_resp) {
      var created_utc, data, proofData, proof_response;
      if (debugMode) {
        console.log("MegaMegaMonitor Debug: proof of identity requested - finding proof");
      }
      proofData = JSON.parse(pr_resp.responseText);
      if (debugMode) {
        console.log(proofData);
      }
      created_utc = "" + (parseInt(proofData.data.created_utc));
      proof_response = md5(created_utc);
      if (debugMode) {
        console.log("MegaMegaMonitor Debug: proof response - " + proof_response);
      }
      url = 'https://www.megamegamonitor.com/identify.php';
      data = "version=121.1437492279&username=" + username + "&proof=" + proof_response;
      if (debugMode) {
        console.log("POST " + url + " " + data);
      }
      return GM_xmlhttpRequest({
        method: 'POST',
        url: url,
        data: data,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        onload: function(pr_resp2) {
          var new_accesskey;
          if (debugMode) {
            console.log("MegaMegaMonitor Debug: proof provided");
          }
          proofData = JSON.parse(pr_resp2.responseText);
          if (debugMode) {
            console.log(proofData);
          }
          if (proofData.proof != null) {
            if (debugMode) {
              console.log("MegaMegaMonitor Debug: proof failed");
            }
            return alert("MegaMegaMonitor wasn't able to verify your identity and will not run. If this problem persists, contact /u/avapoet for help.");
          } else if (proofData.accesskey != null) {
            new_accesskey = proofData.accesskey;
            if (debugMode) {
              console.log("MegaMegaMonitor Debug: proof succeeded - associating accesskey " + new_accesskey + " with username " + username);
            }
            accesskeys[username] = new_accesskey;
            GM_setValue('accesskeys', JSON.stringify(accesskeys));
            return updateUserData();
          }
        }
      });
    }
  });
};

updateUserData = function() {
  if (debugMode) {
    console.log('MegaMegaMonitor Debug: updateUserData()');
  }
  return GM_xmlhttpRequest({
    method: 'GET',
    url: '/api/me.json',
    onload: function(resp1) {
      var data, url, username;
      username = JSON.parse(resp1.responseText).data.name;
      url = 'https://www.megamegamonitor.com/identify.php';
      data = "version=121.1437492279&username=" + username + "&accesskey=" + accesskeys[username];
      if (debugMode) {
        console.log("POST " + url + " " + data);
      }
      return GM_xmlhttpRequest({
        method: 'POST',
        url: url,
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
          if (userData.error != null) {
            if (debugMode) {
              console.log('MegaMegaMonitor Debug: updateUserData() - response received - error');
            }
            return alert(userData.error);
          } else if (userData.proof != null) {
            if (debugMode) {
              console.log('MegaMegaMonitor Debug: updateUserData() - response received - proof');
            }
            return proveIdentity(username, userData.proof);
          } else {
            if (debugMode) {
              console.log('MegaMegaMonitor Debug: updateUserData() - response received - data');
            }
            GM_setValue('userData', JSON.stringify(userData));
            lastUpdated = Date.now();
            GM_setValue('lastUpdated', JSON.stringify(lastUpdated));
            if (debugMode) {
              console.log('MegaMegaMonitor Debug: updateUserData() - saved new values');
            }
            $('#mmm-id').remove();
            return modifyPage();
          }
        }
      });
    }
  });
};

modifyPage = function() {
  var body, sitetable, thisLounge;
  if ((window.location.pathname === "/r/MegaMegaMonitor/wiki/options") && ($('#mmm-options').length === 0)) {
    mmmOptions();
  }
  if ($('#mmm-id').length === 0) {
    $('#header-bottom-right .user').before('<span id="mmm-id" style="margin-right: 8px;">MMM</span>');
    $('#mmm-id').hover(function() {
      var betweenOne, betweenThree, betweenTwo, m_l, out, w_e, w_t;
      clearTimeout(window.mmmIdTipRemover);
      betweenOne = userData.createdAtEnd != null ? new Date(userData.createdAtEnd).toRelativeTime() : 'some time ago';
      betweenTwo = userData.createdAtStart != null ? new Date(userData.createdAtStart).toRelativeTime() : 'some time ago';
      betweenThree = new Date(lastUpdated).toRelativeTime();
      out = "<div class=\"mmm-tip-id\">\n  <p><strong>MegaMegaMonitor</strong></p>\n  <p>\n    <strong>Version:</strong> 121.1437492279<br />\n    <strong>Data max age:</strong> " + betweenTwo + " (<a href=\"#\" id=\"mmm-update-now\">check for update?</a>)\n  </p>\n  <ul>\n    <li><a href=\"/r/MegaMegaMonitor/wiki/options\" id=\"mmm-options\">Options/Tools</a></li>\n    <li><a href=\"/r/MegaMegaMonitor\">Help</a></li>\n  </ul>\n</div>";
      $(this).append(out);
      w_t = $('.mmm-tip').outerWidth();
      w_e = $(this).width();
      m_l = w_e / 2 - (w_t / 2);
      $('.mmm-tip').css('margin-left', m_l + 'px');
      $(this).removeAttr('title');
      return $('.mmm-tip').fadeIn(200);
    }, function() {
      return window.mmmIdTipRemover = setTimeout(function() {
        return $('.mmm-tip-id').remove();
      }, 200);
    });
    $('#mmm-id').on('click', '#mmm-update-now', function() {
      $('#mmm-id').text('MMM updating...');
      updateUserData();
      return false;
    }).on('click', '#mmm-options', mmmOptions);
  }
  body = $('body');
  sitetable = $('.sitetable, .wiki-page-content');
  if (debugMode) {
    if (body.hasClass('profile-page') && !body.hasClass('mmm-profile-page-modified')) {
      if (debugMode) {
        console.log("MegaMegaMonitor Debug: viewing a profile page");
      }
      $('.trophy-area').closest('.spacer').before("<div class=\"spacer\"><div class=\"sidecontentbox mmm-gossip-area\"><a class=\"helplink\" href=\"/r/megamegamonitor/wiki/gossip\">what's this?</a><div class=\"title\"><h1>GOSSIP</h1></div><ul class=\"content\" id=\"mmm-gossip-area-content\"><li>hi there</li></ul></div></div>");
      body.addClass('mmm-profile-page-modified');
    }
  }
  if (sitetable.find('.author:not(.mmm-ran), a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').length === 0) {
    if (debugMode) {
      console.log('MegaMegaMonitor Debug: modifyPage() skipping (nothing to do!)');
    }
    setTimeout(modifyPage, 2500);
    return false;
  }
  thisLounge = ($('#header-img').attr('alt') || '').toLowerCase();
  $('.mmm-icon:not(.mmm-icon-crypto)').remove();
  $('.content a.author.mmm-ran').removeClass('mmm-ran');
  sitetable.find('.author:not(.mmm-ran)').each(function() {
    var cssClass, extraClasses, i, iconHtmlTmp, sub, suppressionId, tip, user, user_userData;
    user = $(this).attr('href').split('/').pop();
    if (user_userData = userData.users[user]) {
      if (user_userData.iconHtml != null) {
        return $(this).after(user_userData.iconHtml);
      } else {
        iconHtmlTmp = '';
        for (i in user_userData) {
          cssClass = user_userData[i][0];
          tip = user_userData[i][1];
          sub = user_userData[i][2];
          suppressionId = user_userData[i][3];
          if (suppressionList.indexOf(suppressionId) === -1) {
            extraClasses = '';
            if (tip.toLowerCase() === thisLounge) {
              extraClasses += ' mmm-icon-current';
            }
            if (iconsize === 'tiny') {
              extraClasses += ' mmm-icon-tiny';
            }
            iconHtmlTmp += "<span data-sub=\"" + sub + "\" data-tip=\"" + tip + "\" class=\"mmm-icon " + cssClass + extraClasses + "\"></span>";
          }
        }
        user_userData.iconHtml = iconHtmlTmp;
        return $(this).after(user_userData.iconHtml);
      }
    }
  });
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
    return $('.mmm-tip').fadeIn(200);
  }), function() {
    return $('.mmm-tip').remove();
  }).dblclick(function() {
    var tip_sub;
    tip_sub = $(this).data('sub');
    if (tip_sub !== '') {
      return window.location.href = '/r/' + tip_sub;
    }
  });
  if (debugMode) {
    console.log('MegaMegaMonitor Debug: considering decrypting things...');
  }
  $('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').each(function() {
    var ciphertext, container, converter, err, html, j, k, key, key_id, key_sub, known_keys, len, len1, mmm_c_crypto, mmm_c_mySub, plaintext, plaintext_icon, ref, ref1, spriteset_position_sub;
    if (debugMode) {
      console.log('MegaMegaMonitor Debug: decrypting something!');
    }
    ciphertext = $(this).attr('title').split(':');
    key = '';
    key_sub = '';
    spriteset_position_sub = 0;
    key_id = parseInt(ciphertext[0]);
    if (debugMode) {
      console.log("MegaMegaMonitor: Attempting to decrypting ciphertext \"" + ciphertext[1] + "\"");
    }
    ref = userData.mySubreddits;
    for (j = 0, len = ref.length; j < len; j++) {
      mmm_c_mySub = ref[j];
      ref1 = mmm_c_mySub.cryptos;
      for (k = 0, len1 = ref1.length; k < len1; k++) {
        mmm_c_crypto = ref1[k];
        if (mmm_c_crypto[0] === key_id) {
          key = mmm_c_crypto[1];
          key_sub = mmm_c_mySub.display_name;
          spriteset_position_sub = mmm_c_mySub.spriteset_position;
        }
      }
    }
    if (key !== '') {
      if (debugMode) {
        console.log("MegaMegaMonitor: Attempting to decrypt using key \"" + key + "\"");
      }
      if ($(this).next().hasClass('keyNavAnnotation')) {
        $(this).next().remove();
      }
      container = $(this).closest('p');
      try {
        plaintext = CryptoJS.AES.decrypt(ciphertext[1], key).toString(CryptoJS.enc.Utf8);
        converter = new Showdown.converter;
        html = converter.makeHtml(plaintext);
        plaintext_icon = "<span data-sub=\"" + key_sub + "\" data-tip=\"Encrypted for " + key_sub + " members only.\" class=\"mmm-icon mmm-icon-crypto mmm-icon-" + spriteset_position_sub + "\"></span>";
        if (container.text() === $(this).text()) {
          return container.replaceWith("<div class=\"mmm-crypto-plaintext\" data-sub=\"" + key_sub + "\">" + plaintext_icon + " " + html + "</div>");
        } else {
          return $(this).replaceWith("<span class=\"mmm-crypto-plaintext\" data-sub=\"" + key_sub + "\">" + plaintext_icon + " " + (html.substring(3, html.length - 4)) + "</span>");
        }
      } catch (_error) {
        err = _error;
        if (debugMode) {
          return console.log('MegaMegaMonitor: Decryption error while decrypting ciphertext "' + ciphertext[1] + '" using key #' + key_id + ': ' + err);
        }
      }
    } else {
      if (debugMode) {
        known_keys = userData.mySubreddits.map(function(sub_with_key) {
          return sub_with_key.id;
        });
        console.log("MegaMegaMonitor: Don't have an appropriate key (searched for " + key_id + ", only found " + (known_keys.join(', ')) + ")");
      }
      return $(this).removeAttr('title');
    }
  });
  sitetable.find('.author').addClass('mmm-ran');
  return setTimeout(modifyPage, 2500);
};

if (("" + lastVersion) === '121.1437492279') {
  if (debugMode) {
    console.log("MegaMegaMonitor Debug: version (" + lastVersion + ") is current");
  }
  userData = JSON.parse(GM_getValue('userData', 'null'));
  lastUpdated = JSON.parse(GM_getValue('lastUpdated', 0));
  if (debugMode) {
    console.log(userData);
  }
  if (debugMode) {
    console.log("(last updated " + lastUpdated + ")");
  }
} else {
  if (debugMode) {
    console.log("MegaMegaMonitor Debug: version (" + lastVersion + ") is not current (121.1437492279)");
  }
}

dataAge = Date.now() - lastUpdated;

suppressionList = JSON.parse(GM_getValue('suppressionList', '[]'));

if (debugMode) {
  console.log("MegaMegaMonitor Debug: loaded suppressionList = " + (JSON.stringify(suppressionList)));
}

$('head').append('<style type="text/css" id="mmm-css-block">.mmm-id{cursor:help}.mmm-tip,.mmm-tip-id{font-size:10px!important;color:#000!important;background:none repeat scroll 0 0 #FFF!important;margin-top:32px;z-index:999999;border:1px solid #000;position:absolute;padding:4px}.mmm-tip a,.mmm-tip-id a{color:#00f!important;text-decoration:underline!important}.mmm-tip-id{margin-top:4px}.mmm-tip-id p{margin:4px 0!important}.mmm-tip-id *{font-size:12px!important;line-height:14px!important}.mmm-tip-id strong{font-weight:bold;text-decoration:underline}.mmm-icon{display:inline-block;width:32px;height:24px;background:url(https://d1wjam29zgrnhb.cloudfront.net/icons122c.png) no-repeat 0 0;margin:0 1px}.mmm-icon.mmm-icon-tiny{width:16px;height:12px;background-size:48px}.mmm-icon.mmm-icon-64{background-position:0 -1536px}.mmm-icon.mmm-icon-68{background-position:0 -1632px}.mmm-icon.mmm-icon-tiny.mmm-icon-64{background-position:0 -768px}.mmm-icon.mmm-icon-tiny.mmm-icon-68{background-position:0 -816px}.mmm-crypto-plaintext{background:#ccc;color:#555}div.mmm-crypto-plaintext{margin-top:3px;margin-bottom:3px}div.mmm-crypto-plaintext>p{display:inline-block;vertical-align:top}.mmm-crypto-plaintext:hover{background:#999;color:#000}.mmm-crypto-plaintext .mmm-icon-crypto{margin-top:3px}ul#mmm-options-hidden-subs,ul#mmm-options-hidden-subs li{list-style:none}.mmm-venn-icon{display:inline-block;width:29px;height:16px;background:url(https://d1wjam29zgrnhb.cloudfront.net/venn2.png) no-repeat 0 0}.mmm-venn-icon.mmm-venn-icon-2minus1{background-position:0 -16px}.mmm-venn-icon.mmm-venn-icon-intersection{background-position:0 -32px}.mmm-venn-icon.mmm-venn-icon-1plus2{background-position:0 -48px}.mmm-debugMode-only{display:none}body.mmm-debugMode .mmm-debugMode-only{display:block}.mmm-pirate-only,.mmm-ninja-only{display:none}.mmm-i-am-a-pirate .mmm-pirate-only,.mmm-i-am-a-ninja .mmm-ninja-only{display:block}.mmm-icon.mmm-icon-1{background-position:0 -24px}.mmm-icon.mmm-icon-1.mmm-icon-current{background-position:-32px -24px}.mmm-icon.mmm-icon-1-plus{background-position:-64px -24px}.mmm-icon.mmm-icon-tiny.mmm-icon-1{background-position:0 -12px}.mmm-icon.mmm-icon-tiny.mmm-icon-1.mmm-icon-current{background-position:-16px -12px}.mmm-icon.mmm-icon-tiny.mmm-icon-1-plus{background-position:-32px -12px}.mmm-icon.mmm-icon-2{background-position:0 -48px}.mmm-icon.mmm-icon-2.mmm-icon-current{background-position:-32px -48px}.mmm-icon.mmm-icon-2-plus{background-position:-64px -48px}.mmm-icon.mmm-icon-tiny.mmm-icon-2{background-position:0 -24px}.mmm-icon.mmm-icon-tiny.mmm-icon-2.mmm-icon-current{background-position:-16px -24px}.mmm-icon.mmm-icon-tiny.mmm-icon-2-plus{background-position:-32px -24px}.mmm-icon.mmm-icon-3{background-position:0 -72px}.mmm-icon.mmm-icon-3.mmm-icon-current{background-position:-32px -72px}.mmm-icon.mmm-icon-3-plus{background-position:-64px -72px}.mmm-icon.mmm-icon-tiny.mmm-icon-3{background-position:0 -36px}.mmm-icon.mmm-icon-tiny.mmm-icon-3.mmm-icon-current{background-position:-16px -36px}.mmm-icon.mmm-icon-tiny.mmm-icon-3-plus{background-position:-32px -36px}.mmm-icon.mmm-icon-4{background-position:0 -96px}.mmm-icon.mmm-icon-4.mmm-icon-current{background-position:-32px -96px}.mmm-icon.mmm-icon-4-plus{background-position:-64px -96px}.mmm-icon.mmm-icon-tiny.mmm-icon-4{background-position:0 -48px}.mmm-icon.mmm-icon-tiny.mmm-icon-4.mmm-icon-current{background-position:-16px -48px}.mmm-icon.mmm-icon-tiny.mmm-icon-4-plus{background-position:-32px -48px}.mmm-icon.mmm-icon-5{background-position:0 -120px}.mmm-icon.mmm-icon-5.mmm-icon-current{background-position:-32px -120px}.mmm-icon.mmm-icon-5-plus{background-position:-64px -120px}.mmm-icon.mmm-icon-tiny.mmm-icon-5{background-position:0 -60px}.mmm-icon.mmm-icon-tiny.mmm-icon-5.mmm-icon-current{background-position:-16px -60px}.mmm-icon.mmm-icon-tiny.mmm-icon-5-plus{background-position:-32px -60px}.mmm-icon.mmm-icon-6{background-position:0 -144px}.mmm-icon.mmm-icon-6.mmm-icon-current{background-position:-32px -144px}.mmm-icon.mmm-icon-6-plus{background-position:-64px -144px}.mmm-icon.mmm-icon-tiny.mmm-icon-6{background-position:0 -72px}.mmm-icon.mmm-icon-tiny.mmm-icon-6.mmm-icon-current{background-position:-16px -72px}.mmm-icon.mmm-icon-tiny.mmm-icon-6-plus{background-position:-32px -72px}.mmm-icon.mmm-icon-7{background-position:0 -168px}.mmm-icon.mmm-icon-7.mmm-icon-current{background-position:-32px -168px}.mmm-icon.mmm-icon-7-plus{background-position:-64px -168px}.mmm-icon.mmm-icon-tiny.mmm-icon-7{background-position:0 -84px}.mmm-icon.mmm-icon-tiny.mmm-icon-7.mmm-icon-current{background-position:-16px -84px}.mmm-icon.mmm-icon-tiny.mmm-icon-7-plus{background-position:-32px -84px}.mmm-icon.mmm-icon-8{background-position:0 -192px}.mmm-icon.mmm-icon-8.mmm-icon-current{background-position:-32px -192px}.mmm-icon.mmm-icon-8-plus{background-position:-64px -192px}.mmm-icon.mmm-icon-tiny.mmm-icon-8{background-position:0 -96px}.mmm-icon.mmm-icon-tiny.mmm-icon-8.mmm-icon-current{background-position:-16px -96px}.mmm-icon.mmm-icon-tiny.mmm-icon-8-plus{background-position:-32px -96px} .mmm-icon.mmm-icon-9{background-position:0 -216px}.mmm-icon.mmm-icon-9.mmm-icon-current{background-position:-32px -216px}.mmm-icon.mmm-icon-9-plus{background-position:-64px -216px}.mmm-icon.mmm-icon-tiny.mmm-icon-9{background-position:0 -108px}.mmm-icon.mmm-icon-tiny.mmm-icon-9.mmm-icon-current{background-position:-16px -108px}.mmm-icon.mmm-icon-tiny.mmm-icon-9-plus{background-position:-32px -108px}.mmm-icon.mmm-icon-10{background-position:0 -240px}.mmm-icon.mmm-icon-10.mmm-icon-current{background-position:-32px -240px}.mmm-icon.mmm-icon-10-plus{background-position:-64px -240px}.mmm-icon.mmm-icon-tiny.mmm-icon-10{background-position:0 -120px}.mmm-icon.mmm-icon-tiny.mmm-icon-10.mmm-icon-current{background-position:-16px -120px}.mmm-icon.mmm-icon-tiny.mmm-icon-10-plus{background-position:-32px -120px}.mmm-icon.mmm-icon-11{background-position:0 -264px}.mmm-icon.mmm-icon-11.mmm-icon-current{background-position:-32px -264px}.mmm-icon.mmm-icon-11-plus{background-position:-64px -264px}.mmm-icon.mmm-icon-tiny.mmm-icon-11{background-position:0 -132px}.mmm-icon.mmm-icon-tiny.mmm-icon-11.mmm-icon-current{background-position:-16px -132px}.mmm-icon.mmm-icon-tiny.mmm-icon-11-plus{background-position:-32px -132px}.mmm-icon.mmm-icon-12{background-position:0 -288px}.mmm-icon.mmm-icon-12.mmm-icon-current{background-position:-32px -288px}.mmm-icon.mmm-icon-12-plus{background-position:-64px -288px}.mmm-icon.mmm-icon-tiny.mmm-icon-12{background-position:0 -144px}.mmm-icon.mmm-icon-tiny.mmm-icon-12.mmm-icon-current{background-position:-16px -144px}.mmm-icon.mmm-icon-tiny.mmm-icon-12-plus{background-position:-32px -144px}.mmm-icon.mmm-icon-13{background-position:0 -312px}.mmm-icon.mmm-icon-13.mmm-icon-current{background-position:-32px -312px}.mmm-icon.mmm-icon-13-plus{background-position:-64px -312px}.mmm-icon.mmm-icon-tiny.mmm-icon-13{background-position:0 -156px}.mmm-icon.mmm-icon-tiny.mmm-icon-13.mmm-icon-current{background-position:-16px -156px}.mmm-icon.mmm-icon-tiny.mmm-icon-13-plus{background-position:-32px -156px}.mmm-icon.mmm-icon-14{background-position:0 -336px}.mmm-icon.mmm-icon-14.mmm-icon-current{background-position:-32px -336px}.mmm-icon.mmm-icon-14-plus{background-position:-64px -336px}.mmm-icon.mmm-icon-tiny.mmm-icon-14{background-position:0 -168px}.mmm-icon.mmm-icon-tiny.mmm-icon-14.mmm-icon-current{background-position:-16px -168px}.mmm-icon.mmm-icon-tiny.mmm-icon-14-plus{background-position:-32px -168px}.mmm-icon.mmm-icon-15{background-position:0 -360px}.mmm-icon.mmm-icon-15.mmm-icon-current{background-position:-32px -360px}.mmm-icon.mmm-icon-15-plus{background-position:-64px -360px}.mmm-icon.mmm-icon-tiny.mmm-icon-15{background-position:0 -180px}.mmm-icon.mmm-icon-tiny.mmm-icon-15.mmm-icon-current{background-position:-16px -180px}.mmm-icon.mmm-icon-tiny.mmm-icon-15-plus{background-position:-32px -180px}.mmm-icon.mmm-icon-16{background-position:0 -384px}.mmm-icon.mmm-icon-16.mmm-icon-current{background-position:-32px -384px}.mmm-icon.mmm-icon-16-plus{background-position:-64px -384px}.mmm-icon.mmm-icon-tiny.mmm-icon-16{background-position:0 -192px}.mmm-icon.mmm-icon-tiny.mmm-icon-16.mmm-icon-current{background-position:-16px -192px}.mmm-icon.mmm-icon-tiny.mmm-icon-16-plus{background-position:-32px -192px}.mmm-icon.mmm-icon-17{background-position:0 -408px}.mmm-icon.mmm-icon-17.mmm-icon-current{background-position:-32px -408px}.mmm-icon.mmm-icon-17-plus{background-position:-64px -408px}.mmm-icon.mmm-icon-tiny.mmm-icon-17{background-position:0 -204px}.mmm-icon.mmm-icon-tiny.mmm-icon-17.mmm-icon-current{background-position:-16px -204px}.mmm-icon.mmm-icon-tiny.mmm-icon-17-plus{background-position:-32px -204px}.mmm-icon.mmm-icon-18{background-position:0 -432px}.mmm-icon.mmm-icon-18.mmm-icon-current{background-position:-32px -432px}.mmm-icon.mmm-icon-18-plus{background-position:-64px -432px}.mmm-icon.mmm-icon-tiny.mmm-icon-18{background-position:0 -216px}.mmm-icon.mmm-icon-tiny.mmm-icon-18.mmm-icon-current{background-position:-16px -216px}.mmm-icon.mmm-icon-tiny.mmm-icon-18-plus{background-position:-32px -216px}.mmm-icon.mmm-icon-19{background-position:0 -456px}.mmm-icon.mmm-icon-19.mmm-icon-current{background-position:-32px -456px}.mmm-icon.mmm-icon-19-plus{background-position:-64px -456px}.mmm-icon.mmm-icon-tiny.mmm-icon-19{background-position:0 -228px}.mmm-icon.mmm-icon-tiny.mmm-icon-19.mmm-icon-current{background-position:-16px -228px}.mmm-icon.mmm-icon-tiny.mmm-icon-19-plus{background-position:-32px -228px}.mmm-icon.mmm-icon-20{background-position:0 -480px}.mmm-icon.mmm-icon-20.mmm-icon-current{background-position:-32px -480px}.mmm-icon.mmm-icon-20-plus{background-position:-64px -480px}.mmm-icon.mmm-icon-tiny.mmm-icon-20{background-position:0 -240px}.mmm-icon.mmm-icon-tiny.mmm-icon-20.mmm-icon-current{background-position:-16px -240px}.mmm-icon.mmm-icon-tiny.mmm-icon-20-plus{background-position:-32px -240px}.mmm-icon.mmm-icon-21{background-position:0 -504px}.mmm-icon.mmm-icon-21.mmm-icon-current{background-position:-32px -504px} .mmm-icon.mmm-icon-21-plus{background-position:-64px -504px}.mmm-icon.mmm-icon-tiny.mmm-icon-21{background-position:0 -252px}.mmm-icon.mmm-icon-tiny.mmm-icon-21.mmm-icon-current{background-position:-16px -252px}.mmm-icon.mmm-icon-tiny.mmm-icon-21-plus{background-position:-32px -252px}.mmm-icon.mmm-icon-22{background-position:0 -528px}.mmm-icon.mmm-icon-22.mmm-icon-current{background-position:-32px -528px}.mmm-icon.mmm-icon-22-plus{background-position:-64px -528px}.mmm-icon.mmm-icon-tiny.mmm-icon-22{background-position:0 -264px}.mmm-icon.mmm-icon-tiny.mmm-icon-22.mmm-icon-current{background-position:-16px -264px}.mmm-icon.mmm-icon-tiny.mmm-icon-22-plus{background-position:-32px -264px}.mmm-icon.mmm-icon-23{background-position:0 -552px}.mmm-icon.mmm-icon-23.mmm-icon-current{background-position:-32px -552px}.mmm-icon.mmm-icon-23-plus{background-position:-64px -552px}.mmm-icon.mmm-icon-tiny.mmm-icon-23{background-position:0 -276px}.mmm-icon.mmm-icon-tiny.mmm-icon-23.mmm-icon-current{background-position:-16px -276px}.mmm-icon.mmm-icon-tiny.mmm-icon-23-plus{background-position:-32px -276px}.mmm-icon.mmm-icon-24{background-position:0 -576px}.mmm-icon.mmm-icon-24.mmm-icon-current{background-position:-32px -576px}.mmm-icon.mmm-icon-24-plus{background-position:-64px -576px}.mmm-icon.mmm-icon-tiny.mmm-icon-24{background-position:0 -288px}.mmm-icon.mmm-icon-tiny.mmm-icon-24.mmm-icon-current{background-position:-16px -288px}.mmm-icon.mmm-icon-tiny.mmm-icon-24-plus{background-position:-32px -288px}.mmm-icon.mmm-icon-25{background-position:0 -600px}.mmm-icon.mmm-icon-25.mmm-icon-current{background-position:-32px -600px}.mmm-icon.mmm-icon-25-plus{background-position:-64px -600px}.mmm-icon.mmm-icon-tiny.mmm-icon-25{background-position:0 -300px}.mmm-icon.mmm-icon-tiny.mmm-icon-25.mmm-icon-current{background-position:-16px -300px}.mmm-icon.mmm-icon-tiny.mmm-icon-25-plus{background-position:-32px -300px}.mmm-icon.mmm-icon-26{background-position:0 -624px}.mmm-icon.mmm-icon-26.mmm-icon-current{background-position:-32px -624px}.mmm-icon.mmm-icon-26-plus{background-position:-64px -624px}.mmm-icon.mmm-icon-tiny.mmm-icon-26{background-position:0 -312px}.mmm-icon.mmm-icon-tiny.mmm-icon-26.mmm-icon-current{background-position:-16px -312px}.mmm-icon.mmm-icon-tiny.mmm-icon-26-plus{background-position:-32px -312px}.mmm-icon.mmm-icon-27{background-position:0 -648px}.mmm-icon.mmm-icon-27.mmm-icon-current{background-position:-32px -648px}.mmm-icon.mmm-icon-27-plus{background-position:-64px -648px}.mmm-icon.mmm-icon-tiny.mmm-icon-27{background-position:0 -324px}.mmm-icon.mmm-icon-tiny.mmm-icon-27.mmm-icon-current{background-position:-16px -324px}.mmm-icon.mmm-icon-tiny.mmm-icon-27-plus{background-position:-32px -324px}.mmm-icon.mmm-icon-28{background-position:0 -672px}.mmm-icon.mmm-icon-28.mmm-icon-current{background-position:-32px -672px}.mmm-icon.mmm-icon-28-plus{background-position:-64px -672px}.mmm-icon.mmm-icon-tiny.mmm-icon-28{background-position:0 -336px}.mmm-icon.mmm-icon-tiny.mmm-icon-28.mmm-icon-current{background-position:-16px -336px}.mmm-icon.mmm-icon-tiny.mmm-icon-28-plus{background-position:-32px -336px}.mmm-icon.mmm-icon-29{background-position:0 -696px}.mmm-icon.mmm-icon-29.mmm-icon-current{background-position:-32px -696px}.mmm-icon.mmm-icon-29-plus{background-position:-64px -696px}.mmm-icon.mmm-icon-tiny.mmm-icon-29{background-position:0 -348px}.mmm-icon.mmm-icon-tiny.mmm-icon-29.mmm-icon-current{background-position:-16px -348px}.mmm-icon.mmm-icon-tiny.mmm-icon-29-plus{background-position:-32px -348px}.mmm-icon.mmm-icon-30{background-position:0 -720px}.mmm-icon.mmm-icon-30.mmm-icon-current{background-position:-32px -720px}.mmm-icon.mmm-icon-30-plus{background-position:-64px -720px}.mmm-icon.mmm-icon-tiny.mmm-icon-30{background-position:0 -360px}.mmm-icon.mmm-icon-tiny.mmm-icon-30.mmm-icon-current{background-position:-16px -360px}.mmm-icon.mmm-icon-tiny.mmm-icon-30-plus{background-position:-32px -360px}.mmm-icon.mmm-icon-31{background-position:0 -744px}.mmm-icon.mmm-icon-31.mmm-icon-current{background-position:-32px -744px}.mmm-icon.mmm-icon-31-plus{background-position:-64px -744px}.mmm-icon.mmm-icon-tiny.mmm-icon-31{background-position:0 -372px}.mmm-icon.mmm-icon-tiny.mmm-icon-31.mmm-icon-current{background-position:-16px -372px}.mmm-icon.mmm-icon-tiny.mmm-icon-31-plus{background-position:-32px -372px}.mmm-icon.mmm-icon-32{background-position:0 -768px}.mmm-icon.mmm-icon-32.mmm-icon-current{background-position:-32px -768px}.mmm-icon.mmm-icon-32-plus{background-position:-64px -768px}.mmm-icon.mmm-icon-tiny.mmm-icon-32{background-position:0 -384px}.mmm-icon.mmm-icon-tiny.mmm-icon-32.mmm-icon-current{background-position:-16px -384px}.mmm-icon.mmm-icon-tiny.mmm-icon-32-plus{background-position:-32px -384px}.mmm-icon.mmm-icon-33{background-position:0 -792px}.mmm-icon.mmm-icon-33.mmm-icon-current{background-position:-32px -792px}.mmm-icon.mmm-icon-33-plus{background-position:-64px -792px}.mmm-icon.mmm-icon-tiny.mmm-icon-33{background-position:0 -396px} .mmm-icon.mmm-icon-tiny.mmm-icon-33.mmm-icon-current{background-position:-16px -396px}.mmm-icon.mmm-icon-tiny.mmm-icon-33-plus{background-position:-32px -396px}.mmm-icon.mmm-icon-34{background-position:0 -816px}.mmm-icon.mmm-icon-34.mmm-icon-current{background-position:-32px -816px}.mmm-icon.mmm-icon-34-plus{background-position:-64px -816px}.mmm-icon.mmm-icon-tiny.mmm-icon-34{background-position:0 -408px}.mmm-icon.mmm-icon-tiny.mmm-icon-34.mmm-icon-current{background-position:-16px -408px}.mmm-icon.mmm-icon-tiny.mmm-icon-34-plus{background-position:-32px -408px}.mmm-icon.mmm-icon-35{background-position:0 -840px}.mmm-icon.mmm-icon-35.mmm-icon-current{background-position:-32px -840px}.mmm-icon.mmm-icon-35-plus{background-position:-64px -840px}.mmm-icon.mmm-icon-tiny.mmm-icon-35{background-position:0 -420px}.mmm-icon.mmm-icon-tiny.mmm-icon-35.mmm-icon-current{background-position:-16px -420px}.mmm-icon.mmm-icon-tiny.mmm-icon-35-plus{background-position:-32px -420px}.mmm-icon.mmm-icon-36{background-position:0 -864px}.mmm-icon.mmm-icon-36.mmm-icon-current{background-position:-32px -864px}.mmm-icon.mmm-icon-36-plus{background-position:-64px -864px}.mmm-icon.mmm-icon-tiny.mmm-icon-36{background-position:0 -432px}.mmm-icon.mmm-icon-tiny.mmm-icon-36.mmm-icon-current{background-position:-16px -432px}.mmm-icon.mmm-icon-tiny.mmm-icon-36-plus{background-position:-32px -432px}.mmm-icon.mmm-icon-37{background-position:0 -888px}.mmm-icon.mmm-icon-37.mmm-icon-current{background-position:-32px -888px}.mmm-icon.mmm-icon-37-plus{background-position:-64px -888px}.mmm-icon.mmm-icon-tiny.mmm-icon-37{background-position:0 -444px}.mmm-icon.mmm-icon-tiny.mmm-icon-37.mmm-icon-current{background-position:-16px -444px}.mmm-icon.mmm-icon-tiny.mmm-icon-37-plus{background-position:-32px -444px}.mmm-icon.mmm-icon-38{background-position:0 -912px}.mmm-icon.mmm-icon-38.mmm-icon-current{background-position:-32px -912px}.mmm-icon.mmm-icon-38-plus{background-position:-64px -912px}.mmm-icon.mmm-icon-tiny.mmm-icon-38{background-position:0 -456px}.mmm-icon.mmm-icon-tiny.mmm-icon-38.mmm-icon-current{background-position:-16px -456px}.mmm-icon.mmm-icon-tiny.mmm-icon-38-plus{background-position:-32px -456px}.mmm-icon.mmm-icon-39{background-position:0 -936px}.mmm-icon.mmm-icon-39.mmm-icon-current{background-position:-32px -936px}.mmm-icon.mmm-icon-39-plus{background-position:-64px -936px}.mmm-icon.mmm-icon-tiny.mmm-icon-39{background-position:0 -468px}.mmm-icon.mmm-icon-tiny.mmm-icon-39.mmm-icon-current{background-position:-16px -468px}.mmm-icon.mmm-icon-tiny.mmm-icon-39-plus{background-position:-32px -468px}.mmm-icon.mmm-icon-61{background-position:0 -1464px}.mmm-icon.mmm-icon-61.mmm-icon-current{background-position:-32px -1464px}.mmm-icon.mmm-icon-61-plus{background-position:-64px -1464px}.mmm-icon.mmm-icon-tiny.mmm-icon-61{background-position:0 -732px}.mmm-icon.mmm-icon-tiny.mmm-icon-61.mmm-icon-current{background-position:-16px -732px}.mmm-icon.mmm-icon-tiny.mmm-icon-61-plus{background-position:-32px -732px}.mmm-icon.mmm-icon-62{background-position:0 -1488px}.mmm-icon.mmm-icon-62.mmm-icon-current{background-position:-32px -1488px}.mmm-icon.mmm-icon-62-plus{background-position:-64px -1488px}.mmm-icon.mmm-icon-tiny.mmm-icon-62{background-position:0 -744px}.mmm-icon.mmm-icon-tiny.mmm-icon-62.mmm-icon-current{background-position:-16px -744px}.mmm-icon.mmm-icon-tiny.mmm-icon-62-plus{background-position:-32px -744px}.mmm-icon.mmm-icon-63{background-position:0 -1512px}.mmm-icon.mmm-icon-63.mmm-icon-current{background-position:-32px -1512px}.mmm-icon.mmm-icon-63-plus{background-position:-64px -1512px}.mmm-icon.mmm-icon-tiny.mmm-icon-63{background-position:0 -756px}.mmm-icon.mmm-icon-tiny.mmm-icon-63.mmm-icon-current{background-position:-16px -756px}.mmm-icon.mmm-icon-tiny.mmm-icon-63-plus{background-position:-32px -756px}.mmm-icon.mmm-icon-65{background-position:0 -1560px}.mmm-icon.mmm-icon-65.mmm-icon-current{background-position:-32px -1560px}.mmm-icon.mmm-icon-65-plus{background-position:-64px -1560px}.mmm-icon.mmm-icon-tiny.mmm-icon-65{background-position:0 -780px}.mmm-icon.mmm-icon-tiny.mmm-icon-65.mmm-icon-current{background-position:-16px -780px}.mmm-icon.mmm-icon-tiny.mmm-icon-65-plus{background-position:-32px -780px}.mmm-icon.mmm-icon-66{background-position:0 -1584px}.mmm-icon.mmm-icon-66.mmm-icon-current{background-position:-32px -1584px}.mmm-icon.mmm-icon-66-plus{background-position:-64px -1584px}.mmm-icon.mmm-icon-tiny.mmm-icon-66{background-position:0 -792px}.mmm-icon.mmm-icon-tiny.mmm-icon-66.mmm-icon-current{background-position:-16px -792px}.mmm-icon.mmm-icon-tiny.mmm-icon-66-plus{background-position:-32px -792px}.mmm-icon.mmm-icon-67{background-position:0 -1608px}.mmm-icon.mmm-icon-67.mmm-icon-current{background-position:-32px -1608px}.mmm-icon.mmm-icon-67-plus{background-position:-64px -1608px}.mmm-icon.mmm-icon-tiny.mmm-icon-67{background-position:0 -804px}.mmm-icon.mmm-icon-tiny.mmm-icon-67.mmm-icon-current{background-position:-16px -804px} .mmm-icon.mmm-icon-tiny.mmm-icon-67-plus{background-position:-32px -804px}.mmm-icon.mmm-icon-69{background-position:0 -1656px}.mmm-icon.mmm-icon-69.mmm-icon-current{background-position:-32px -1656px}.mmm-icon.mmm-icon-69-plus{background-position:-64px -1656px}.mmm-icon.mmm-icon-tiny.mmm-icon-69{background-position:0 -828px}.mmm-icon.mmm-icon-tiny.mmm-icon-69.mmm-icon-current{background-position:-16px -828px}.mmm-icon.mmm-icon-tiny.mmm-icon-69-plus{background-position:-32px -828px}.mmm-icon.mmm-icon-70{background-position:0 -1680px}.mmm-icon.mmm-icon-70.mmm-icon-current{background-position:-32px -1680px}.mmm-icon.mmm-icon-70-plus{background-position:-64px -1680px}.mmm-icon.mmm-icon-tiny.mmm-icon-70{background-position:0 -840px}.mmm-icon.mmm-icon-tiny.mmm-icon-70.mmm-icon-current{background-position:-16px -840px}.mmm-icon.mmm-icon-tiny.mmm-icon-70-plus{background-position:-32px -840px}.mmm-icon.mmm-icon-71{background-position:0 -1704px}.mmm-icon.mmm-icon-71.mmm-icon-current{background-position:-32px -1704px}.mmm-icon.mmm-icon-71-plus{background-position:-64px -1704px}.mmm-icon.mmm-icon-tiny.mmm-icon-71{background-position:0 -852px}.mmm-icon.mmm-icon-tiny.mmm-icon-71.mmm-icon-current{background-position:-16px -852px}.mmm-icon.mmm-icon-tiny.mmm-icon-71-plus{background-position:-32px -852px}.mmm-icon.mmm-icon-72{background-position:0 -1728px}.mmm-icon.mmm-icon-72.mmm-icon-current{background-position:-32px -1728px}.mmm-icon.mmm-icon-72-plus{background-position:-64px -1728px}.mmm-icon.mmm-icon-tiny.mmm-icon-72{background-position:0 -864px}.mmm-icon.mmm-icon-tiny.mmm-icon-72.mmm-icon-current{background-position:-16px -864px}.mmm-icon.mmm-icon-tiny.mmm-icon-72-plus{background-position:-32px -864px}.mmm-icon.mmm-icon-73{background-position:0 -1752px}.mmm-icon.mmm-icon-73.mmm-icon-current{background-position:-32px -1752px}.mmm-icon.mmm-icon-73-plus{background-position:-64px -1752px}.mmm-icon.mmm-icon-tiny.mmm-icon-73{background-position:0 -876px}.mmm-icon.mmm-icon-tiny.mmm-icon-73.mmm-icon-current{background-position:-16px -876px}.mmm-icon.mmm-icon-tiny.mmm-icon-73-plus{background-position:-32px -876px}.mmm-icon.mmm-icon-74{background-position:0 -1776px}.mmm-icon.mmm-icon-74.mmm-icon-current{background-position:-32px -1776px}.mmm-icon.mmm-icon-74-plus{background-position:-64px -1776px}.mmm-icon.mmm-icon-tiny.mmm-icon-74{background-position:0 -888px}.mmm-icon.mmm-icon-tiny.mmm-icon-74.mmm-icon-current{background-position:-16px -888px}.mmm-icon.mmm-icon-tiny.mmm-icon-74-plus{background-position:-32px -888px}.mmm-icon.mmm-icon-75{background-position:0 -1800px}.mmm-icon.mmm-icon-75.mmm-icon-current{background-position:-32px -1800px}.mmm-icon.mmm-icon-75-plus{background-position:-64px -1800px}.mmm-icon.mmm-icon-tiny.mmm-icon-75{background-position:0 -900px}.mmm-icon.mmm-icon-tiny.mmm-icon-75.mmm-icon-current{background-position:-16px -900px}.mmm-icon.mmm-icon-tiny.mmm-icon-75-plus{background-position:-32px -900px}.mmm-icon.mmm-icon-76{background-position:0 -1824px}.mmm-icon.mmm-icon-76.mmm-icon-current{background-position:-32px -1824px}.mmm-icon.mmm-icon-76-plus{background-position:-64px -1824px}.mmm-icon.mmm-icon-tiny.mmm-icon-76{background-position:0 -912px}.mmm-icon.mmm-icon-tiny.mmm-icon-76.mmm-icon-current{background-position:-16px -912px}.mmm-icon.mmm-icon-tiny.mmm-icon-76-plus{background-position:-32px -912px}.mmm-icon.mmm-icon-77{background-position:0 -1848px}.mmm-icon.mmm-icon-77.mmm-icon-current{background-position:-32px -1848px}.mmm-icon.mmm-icon-77-plus{background-position:-64px -1848px}.mmm-icon.mmm-icon-tiny.mmm-icon-77{background-position:0 -924px}.mmm-icon.mmm-icon-tiny.mmm-icon-77.mmm-icon-current{background-position:-16px -924px}.mmm-icon.mmm-icon-tiny.mmm-icon-77-plus{background-position:-32px -924px}.mmm-icon.mmm-icon-78{background-position:0 -1872px}.mmm-icon.mmm-icon-78.mmm-icon-current{background-position:-32px -1872px}.mmm-icon.mmm-icon-78-plus{background-position:-64px -1872px}.mmm-icon.mmm-icon-tiny.mmm-icon-78{background-position:0 -936px}.mmm-icon.mmm-icon-tiny.mmm-icon-78.mmm-icon-current{background-position:-16px -936px}.mmm-icon.mmm-icon-tiny.mmm-icon-78-plus{background-position:-32px -936px}.mmm-icon.mmm-icon-79{background-position:0 -1896px}.mmm-icon.mmm-icon-79.mmm-icon-current{background-position:-32px -1896px}.mmm-icon.mmm-icon-79-plus{background-position:-64px -1896px}.mmm-icon.mmm-icon-tiny.mmm-icon-79{background-position:0 -948px}.mmm-icon.mmm-icon-tiny.mmm-icon-79.mmm-icon-current{background-position:-16px -948px}.mmm-icon.mmm-icon-tiny.mmm-icon-79-plus{background-position:-32px -948px}</style>');

$('body').addClass('mmm-installed');

if (debugMode) {
  $('body').addClass('mmm-debugMode');
}

if ($('body').hasClass('loggedin')) {
  if (dataAge > 21600000) {
    if (debugMode) {
      console.log("MegaMegaMonitor Debug: At " + dataAge + " seconds old, data is out of date. Updating.");
    }
    updateUserData();
  } else {
    if (debugMode) {
      console.log("MegaMegaMonitor Debug: At " + dataAge + " seconds old, data is fresh. Cool.");
    }
    modifyPage();
  }
}
