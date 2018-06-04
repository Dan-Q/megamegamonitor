# Note to self:
# Beta install example one-liner (Firefox, Windows):
# curl "https://dev.megamegamonitor.com/mmm.user.js?version=155.alpha" > %APPDATA%\Mozilla\Firefox\Profiles\xqnfom3y.default\gm_scripts\MegaMegaMonitor-1\mmm.user.js
# curl "https://dev.megamegamonitor.com/mmm.user.js?version=155.alpha" > %APPDATA%\Mozilla\Firefox\Profiles\j4599dal.default\gm_scripts\MegaMegaMonitor\mmm.user.js

# set up jQuery
@$ = @jQuery = jQuery.noConflict(true)

# Set up MMM container on window
window.mmm = {
  log: [],    # log storage (this page load only, possibly mirrored to console)
  users: {},  # permanent storage space (retained between page loads)
  temp: {}    # temporary storage space (this page load only)
}

# Precache commonly-used jQuery resources
window.mmm.temp.body ?= $('body')
window.mmm.temp.sitetable ?= $('.sitetable, .wiki-page-content, .commentarea, #newlink')

##########################################################################
### Utility polyfills                                                  ###
##########################################################################

# Array.first
# Pass it a boolean function, and it'll return the first item in the array
# that satisfies that function, *without* parsing the whole array if it
# finds a match. Returns null if none found.
if !Array.prototype.first
  Array.prototype.first = (predicate)->
    for item in this
      if predicate(item) then return item
    null

# Array.any
# Backed by Array.first, returns true if any match, false otherwist
if !Array.prototype.any
  Array.prototype.any = (predicate)->
    !!this.first(predicate)

##########################################################################
### JS loading                                                         ###
##########################################################################

MMM_LISTS_JS = CoffeeScript.compile(MMM_LISTS_COFFEE, { bare: true })
eval MMM_LISTS_JS

##########################################################################
### Core functions                                                     ###
##########################################################################

# Logging/status
# Levels:
#  9 - status: update bubble
#  6 - error
#  4 - warning
#  2 - debug
log = (level, message)->
  console.log "MMM:#{level}:#{new Date()}:#{message}"
  window.mmm.log.push { level: level, message: message }
  if level < 9 then return # everything below only applies to user-seen messages
  if ($('#mmm-status').text() == message) then return # Only log status message changes visibly if they actually represent a change
  $('#mmm-status').text(message)

# Returns true if we're on reddit.com, false otherwise
on_reddit_com = ->
  window.location.hostname.search(/reddit.com$/) >= 0

# Returns true if we're on the MegaMegaMonitor options page, false otherwise
on_options_page = ->
  if window.mmm.temp.on_start_page then return false # never show options page when showing start page
  window.location.pathname.toLowerCase() == MMM_OPTIONS_URL.toLowerCase()

# Returns true if we're on the MegaMegaMonitor MegaLounge Map page, false otherwise
on_map_page = ->
  if window.mmm.temp.on_start_page then return false # never show options page when showing start page
  window.location.pathname.toLowerCase() == MMM_MAP_URL.toLowerCase()

# Returns true if we're on the MegaMegaMonitor MegaLounge Tails page, false otherwise
on_tails_page = ->
  if window.mmm.temp.on_start_page then return false # never show options page when showing start page
  window.location.pathname.toLowerCase() == MMM_TAILS_URL.toLowerCase()

# Returns true if we're on the MegaMegaMonitor MegaLounge Changes page, false otherwise
on_changes_page = ->
  if window.mmm.temp.on_start_page then return false # never show options page when showing start page
  window.location.pathname.toLowerCase() == MMM_CHANGES_URL.toLowerCase()

# Add <head> scripts/css
add_head_scripts = ->
  log 2, "Injecting MMM CSS into page (#{MMM_CSS})."
  $('head').append "<style type=\"text/css\" id=\"mmm-css-block\">#{MMM_CSS}</style>"

# Add "MMM" hint icon and bubble
add_mmm_icon = ->
  log 2, "Adding MMM icon and bubble."
  $('#header-bottom-right').prepend """
    <div class="mmm-hint help help-hoverable">
      <a class="mmm-link" href="#{MMM_OPTIONS_URL}">MMM</a>
    </div>
  """
  $('body').append """
    <div id="mmm-help" class="hover-bubble help-bubble anchor-top">
      <div class="help-section">
        <h2><a href="#{MMM_SUBREDDIT_URL}">MMM</a> v#{VERSION}</h2>
        <div id="mmm-bubble">
          <div id="mmm-status"></div>
          <div id="mmm-bubble-actions"></div>
        </div>
      </div>
    </div>
  """
  # On icon hover, show hint icon and bubble
  $('.mmm-link, #mmm-help').hover ->
    clearTimeout window.mmm.mmmHelpTimeout
    show_mmm_bubble()
  , ->
    window.mmm.mmmHelpTimeout = setTimeout ->
      $('#mmm-help').fadeOut()
    , 1000

# Current sub
current_sub = ->
  current_sub_name = $('.side .redditname').text()
  candidates = window.mmm.users[window.mmm.username].icons.data.subs.filter (sub)->
    sub.display_name == current_sub_name
  candidates[0]

# Add megalounge-selector dropdown, if we're on a megalounge
add_megalounge_dropdown = ->
  current = current_sub()
  if !current? then return # if we're not on a detectable sub, skip
  if !current.chain_number then return # we only care about megalounges
  current_sub_name = current.display_name
  $('.side .redditname').before '<p><select id="mmm-megajump" style="width: 100%; margin-top: 18px;"></select></p>'
  mega_jump = $('#mmm-megajump')
  window.mmm.users[window.mmm.username].icons.data.subs.filter (sub)-> 
    !!sub.chain_number
  .forEach (sub)->
    mega_jump.append "<option value=\"#{sub.display_name}\">#{sub.display_name} (#{sub.users.length})</option>"
  mega_jump.val current_sub_name
  mega_jump.on 'change', ->
    window.location.href = "/r/#{$(this).val()}"

# Universal event handling
add_event_handlers = ->
  # showing/hiding crypto interface
  $('body').on 'click', '.mmm-encrypt, .mmm-encrypt-cancel', ->
    $(this).closest('.usertext, .usertext-edit').find('.mmm-textarea-options, .mmm-textarea-options-crypto').toggle()
    false
  # encrypting on-demand
  $('body').on 'click', '.mmm-textarea-options-crypto .mmm-encrypt-go', ->
    textarea = $(this).closest('.usertext, .usertext-edit').find('textarea')
    plaintext = textarea.val().slice(textarea[0].selectionStart, textarea[0].selectionEnd)
    publictext = $(this).closest('.mmm-textarea-options-crypto').find('.mmm-textarea-options-crypto-public').val()
    select = $(this).closest('.mmm-textarea-options-crypto').find('.mmm-textarea-options-crypto-key')
    key_id = select.val()
    key = select.find('option:selected').data('key')
    if plaintext.length > 0
      before_plaintext = textarea.val().slice(0, textarea[0].selectionStart)
      after_plaintext = textarea.val().slice(textarea[0].selectionEnd, textarea.val().length)
      textarea.val("#{before_plaintext}#{encrypt(plaintext, publictext, key_id, key)}#{after_plaintext}")
    else
      alert "No text was selected. You must select some text, first."
    false

show_mmm_bubble = ->
  $('#mmm-help').css
    top: "#{$('.mmm-hint').offset().top + $('.mmm-hint').height() + 5}px"
    left: "#{$('.mmm-hint').offset().left - 388}px"
  .fadeIn()

check_for_update_to_plugin = ->
  $.getJSON PLUGIN_VERSION_URL, (new_version)->
    alert "You are running MMM v#{VERSION}. The latest available version is v#{new_version}."
  false

check_for_update_to_data = ->
  show_mmm_bubble() # always show bubble when manual updating data starts
  $.when(update_icons()).then ->
    force_page_to_require_update()
    update_page()
  false

clear_all_offline_data = ->
  log 2, "Clearing offline data."
  window.localStorage.removeItem('mmm.users')
  window.location.reload()

# Add actions to MMM bubble
add_actions_to_mmm_bubble = ->
  log 2, "Adding actions to MMM bubble."
  $('#mmm-bubble-actions').html """
    <ul>
      <li>
        <a href="#{MMM_OPTIONS_URL}">Options/Tools</a>
      </li>
      <li>
        Check for updates to:
        <a href="#{PLUGIN_INSTALL_URL}" id="mmm-update-check-plugin">MMM?</a> |
        <a href="#" id="mmm-update-check-data">Data?</a>
      </li>
    </ul>
  """
  # Update checker: plugin
  $('#mmm-update-check-plugin').on 'click', check_for_update_to_plugin
  $('#mmm-update-check-data').on 'click', check_for_update_to_data

# Check if we have data AT ALL (even if it's out of date). This is important because we can use it to update the page
# WHILE we update outdated data, if necessary
i_have_icon_data = ->
  window.mmm.users[window.mmm.username] && window.mmm.users[window.mmm.username].icons

# Check the age of the iconset: returns true if absent or outdated, false otherwise
icons_outdated = ->
  log 2, "Checking if icons are outdated."
  if !i_have_icon_data() then return true
  last_updated = window.mmm.users[window.mmm.username].icons.last_updated || 0
  data_age = (new Date().getTime()) - last_updated
  log 2, "Date.now() = #{Date.now()}, last_updated = #{last_updated}, therefore data_age = #{data_age} (MAX_DATA_AGE = #{MAX_DATA_AGE})."
  !data_age || (data_age > MAX_DATA_AGE)

# Updates icons
# Asynchronous (deferred method)
update_icons = ->
  dfd = $.Deferred()
  log 9, "Updating data..."
  # Get data based upon my identity
  $.getJSON DATA_URL, { username: window.mmm.username, accesskey: window.mmm.users[window.mmm.username].accesskey }, (new_data)->
    # Handle error responses
    if new_data.error?
      if new_data.error.code == 'invalid_accesskey'
        # invalid accesskey - let's get a new one
        clear_all_offline_data()
        log 9, "Accesskey invalid... will try to get a new one next refresh..."
      else
        alert "MegaMegaMonitor error:\n#{new_data.error.message}"
      log 9, "Error: #{new_data.error.message}"
    else
      window.mmm.users[window.mmm.username].icons = { last_updated: (new Date().getTime()), data: new_data }
      save_offline_data()
      # strip existing icons etc. so they are forced to be re-drawn based on new data just obtained
      log 9, "Running as normal."
      window.mmm.temp.sitetable.find('.author.mmm-ran').removeClass 'mmm-ran'
      window.mmm.temp.sitetable.find('.mmm-author-icons, .mmm-icon:not(.mmm-icon-crypto)').remove()
      # In case we're on the "first run" page, advise that the initial download is now done!
      $('#mmm-start-setup-running').hide()
      $('#mmm-start-setup-done').show()
      # Resolve the promise
    dfd.resolve()
    dfd.promise()

# Given a username, returns the HTML to suffix a user's username with. Gets this data from the icon cache if possible;
# failing that, precalculates it to the icon cache before returning it to make it faster next time. Automatically saves
# changes to offline data if necessary.
icon_html_for_user = (username)->
  log 2, "Getting icons for #{username}."
  window.mmm.users[window.mmm.username].icons.data.cached ?= { users: {}, ciphers: {} } # set up space for caching e.g. icon HTML for each user
  # Try to load a copy from the cache
  cached_copy = window.mmm.users[window.mmm.username].icons.data.cached.users[username]
  if cached_copy? then return cached_copy # using cached_copy? as the clause rather than cached_copy permits empty strings, as required for most users
  # Generate icons if we don't have them precached
  log 2, "Generating icons for #{username}."
  icon_html_set = []
  found_chain_sub = false
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    if sub.users # only deal with subs that actually have users
      if !found_chain_sub || !sub.chain_number? # only consider adding an icon if we've not yet found a chain sub or this is not a chain sub: prevents duplicate chain icons
        # log 2, " > Looking in #{sub.display_name}." # DEBUG
        user_data = sub.users.first (user_data)->
          user_data[0] == username
        if user_data
          log 2, " > > Found them in #{sub.display_name}!"
          if sub.chain_number? then found_chain_sub = true # tag that we've found their highest chain sub so we stop looking at chain subs
          tip = user_data[1]
          # Add the icon to the list
          extra_classes = ''
          link = "/r/#{sub.display_name}"
          title = sub.display_name
          # If it's a "uses MMM icon", adapt link
          if sub.id == -1 then link = '/r/megamegamonitor'
          # If it's a "higher" icon, adapt text and icon
          if tip == '+'
            extra_classes += ' mmm-icon-plus'
            if sub.id == -1
              # "Uses MegaMegaMonitor" - a 'plus' means 'super special'
              title = "#{title} and is super special!"
            else
              # Assume that this 'plus' means that they're "higher in the chain"
              title = "Higher than #{title}"
          else if tip != ''
            title = "#{title} (#{tip})"
          icon_html_set.push "<a href=\"#{link}\" data-sub=\"#{sub.display_name}\" title=\"#{title}\" class=\"mmm-icon mmm-icon-#{sub.id}#{extra_classes}\"></a>"
  cached_copy = "<div class=\"mmm-author-icons\">#{window.mmm.users[window.mmm.username].icons.data.cached.users[username] = icon_html_set.join(' ')}</div>"
  log 2, " > HTML = #{cached_copy}"
  cached_copy

# Given a crypto element (which is an <a> tag), attempts to decrypt and replace with its plaintext
attempt_to_decrypt = ($elem)->
  # Tag this element as attempted so we don't attempt it again: we do this first to prevent
  # concurrency issues
  $elem.addClass 'mmm-ran'
  # Extract ciphertext/key parts from a#title
  title = $elem.attr('title')
  log 2, "Attempting decryption of #{title}."
  ciphertext = title.split(':')
  key = key_sub = null
  # Find a matching key for this content
  key_id = parseInt(ciphertext[0])
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    for cryptokey in sub.cryptokeys
      if cryptokey[0] == key_id
        # found the key we need
        key = cryptokey[1]
        key_sub = sub
  # If we've successfully found a key, attempt decryption
  if key
    # We have a matching key - decrypt
    log 2, "Using key #{key} (#{key_id}) from #{key_sub.display_name}."
    if $elem.next().hasClass('keyNavAnnotation') then $elem.next().remove() # tidy up in case RES has annotated the link already
    publictext = $elem.html().trim() # store publicly-visible text
    has_publictext = (publictext.length > 0)
    container = $elem.closest('p') # Find containing paragraph
    try
      plaintext = CryptoJS.AES.decrypt(ciphertext[1], key).toString(CryptoJS.enc.Utf8)
      converter = new showdown.Converter()
      html = converter.makeHtml(plaintext)
      plaintext_icon = "<a data-sub=\"#{key_sub.display_name}\" title=\"Encrypted for #{key_sub.display_name} members only.\" class=\"mmm-icon mmm-icon-crypto mmm-icon-#{key_sub.id}\"></a>"
      if container.text() == $elem.text()
        # entire paragraph exists only for crypto: replace entirely
        # TODO: support markdown in publictext
        parent = container.parent()
        container.replaceWith "<div class=\"mmm-crypto-plaintext #{if has_publictext then 'has-publictext' else 'nope'}\" data-sub=\"#{key_sub.display_name}\">#{plaintext_icon} <span class=\"flopped\">#{html}</span><p><a href=\"/r/MegaMegaMonitor/wiki/encrypted\" class=\"flipped\">#{publictext}</a></p></div>"
        parent.find('.mmm-crypto-plaintext').hover ->
          $(this).addClass 'show-publictext'
        , ->
          $(this).removeClass 'show-publictext'
      else
        # "inline" crypto: remove <p> tags from markdown html output and insert inline
        parent = $elem.parent()
        $elem.replaceWith "<span class=\"mmm-crypto-plaintext #{if has_publictext then 'has-publictext' else 'nope'}\" data-sub=\"#{key_sub.display_name}\" data-publictext=\"#{$elem.text()}\">#{plaintext_icon} <span class=\"flopped\">#{html.substring(3, html.length - 4)}</span><a href=\"/r/MegaMegaMonitor/wiki/encrypted\" class=\"flipped\">#{publictext}</a></span>"
        parent.find('.mmm-crypto-plaintext').hover ->
          $(this).addClass 'show-publictext'
        , ->
          $(this).removeClass 'show-publictext'
    catch err
      log 6, "Decryption error: #{err}"
  else
    log 2, 'No suitable decryption key found.'

# Given plaintext, publictext (which can be blank), a key id, and a key, returns a Markdown cryptolink
encrypt = (plaintext, publictext, key_id, key)->
  log 2, "Encrypting: #{plaintext} | #{publictext} | #{key_id} | #{key}"
  ciphertext = CryptoJS.AES.encrypt(plaintext, key).toString()
  "[#{publictext}](/r/MegaMegaMonitor/wiki/encrypted \"#{key_id}:#{ciphertext}\")"

# Adds crypto options etc. to a textarea, provided as a jQuery object $elem
add_textarea_options_to = ($elem)->
  # Check if already tagged this textarea
  if $elem.hasClass('mmm-ran') then return false
  $elem.addClass('mmm-ran')
  log 2, "Adding textarea options to a textarea."
  # Add HTML below this textarea
  # TODO(?): refactor this out into a view
  $container = $elem.parent()
  $elem.after """
    <div class="mmm-textarea-options">
      <a href="#" class="mmm-encrypt" title="Encrypt using MegaMegaMonitor" tabindex="-1">Encrypt</a>
    </div>
    <div class="mmm-textarea-options-crypto" style="display: none;">
      <p>
        Choose who will be able to see the encrypted text below. Select some text above to encrypt.
        Optionally provide text for people who aren't in the sub (or don't use MMM).
      </p>
      <select class="mmm-textarea-options-crypto-key"></select>
      <input type="text" class="mmm-textarea-options-crypto-public" placeholder="public text (optional)" />
      <a href="#" class="mmm-encrypt-go">Encrypt</a>
      <a href="#" class="mmm-encrypt-cancel">Cancel</a>
    </div>
  """
  # Prefill the <select> of cryptokeys
  if !window.mmm.temp.crypto_options
    window.mmm.temp.crypto_options = []
    for sub in window.mmm.users[window.mmm.username].icons.data.subs
      if (sub.cryptokeys || []).length > 0
        sub_name = if (sub.id == -1) then 'Anyone using MegaMegaMonitor' else sub.display_name
        window.mmm.temp.crypto_options.push "<option value=\"#{sub.cryptokeys[0][0]}\" data-key=\"#{sub.cryptokeys[0][1]}\">#{sub_name}</option>"
  $container.find('.mmm-textarea-options-crypto .mmm-textarea-options-crypto-key').html(window.mmm.temp.crypto_options.join(''))

# Loads the recipe book onto the Options -> Lists page
load_recipe_book = ->
  recipe_book = $('#mmm-list-recipebook')
  recipe_book.html('') # remove all existing recipes, we'll re-add all
  # User-made recipes
  for recipe_name of (window.mmm.recipes ?= {})
    recipe_book.append "<option>#{recipe_name}</option>"
  # Sample recipes - MegaLounge Populations
  recipe_book.append "<option>Sample: Contributors</option>"
  recipe_book.append "<option>Sample: Contributors (two pages only)</option>"
  recipe_book.append "<option>Sample: Contributors (with progress)</option>"
  recipe_book.append "<option>Sample: Gildings</option>"
  recipe_book.append "<option>Sample: Intersection</option>"
  recipe_book.append "<option>Sample: In One But Not Another</option>"
  recipe_book.append "<option>Sample: Invite Contributors</option>"
  recipe_book.append "<option>Sample: Invite Contributors From Another</option>"
  recipe_book.append "<option>Sample: Known Subs</option>"
  recipe_book.append "<option>Sample: MegaLounge Populations</option>"
  recipe_book.append "<option>Sample: MMMers</option>"
  recipe_book.append "<option>Sample: Smart Ascender</option>"
  recipe_book.append "<option>Sample: XOR</option>"

# Loads a specified recipe from the book, given its name
load_recipe = (recipe_name)->
  log 2, "Loading recipe: #{recipe_name}"
  if (recipe = (window.mmm.recipes ?= {})[recipe_name])
    $('#mmm-list-code').val recipe
  if(recipe_name == 'Sample: Contributors')
    $('#mmm-list-code').val """
      # Sample: Contributors
      # This recipe lists the people who are in a particular private sub
      # (so long as you have access to that sub).

      SUB = 'MegaLounge'

      # Clear the output area
      List.output.clear()

      # Generate list
      List.subreddit(SUB).contributors().then (contributors)->

        # Output the result
        List.output.log("People in /r/\#{SUB}:")
        for contributor in contributors
          List.output.log(" * \#{contributor}")
  """
  if(recipe_name == 'Sample: Contributors (two pages only)')
    $('#mmm-list-code').val """
      # Sample: Contributors (two pages only)
      # This recipe lists the people who are in a particular private sub
      # (so long as you have access to that sub). It always runs in slow
      # mode but deliberately gets only the first two pages (i.e. up to
      # 200 results) of people back. Replace the 'null' with the
      # callback progress meter from Sample: Contributors (with progress)
      # to see this limiting in action.

      SUB = 'MegaLounge'

      # Clear the output area
      List.output.clear()

      # Run in slow mode (only way to meaningfully demonstrate this)
      List.mode 'slow'

      # Generate list (the '1' states which page [zero-indexed] to stop at)
      List.subreddit(SUB).contributors null, 1
      .then (contributors)->

        # Output the result
        List.output.log("People in /r/\#{SUB}:")
        for contributor in contributors
          List.output.log(" * \#{contributor}")
    """
  if(recipe_name == 'Sample: Contributors (with progress)')
    $('#mmm-list-code').val """
      # Sample: Contributors (with progress)
      # This recipe lists the people who are in a particular private sub
      # (so long as you have access to that sub). It provides an indication
      # of progress as it loads pages of data from Reddit.

      SUB = 'MegaLounge'

      # Run in slow mode (only way to meaningfully demonstrate this)
      List.mode 'slow'

      # Run with a progress meter:
      List.output.clear()
      List.output.log("Generating list of people in /r/\#{SUB}:")

      # Generate list (observe the (p)-> callback 'progress' function)
      List.subreddit(SUB).contributors (p)->
        List.output.log(" > loaded page \#{p}")
      .then (contributors)->

        # Output the result
        List.output.clear()
        List.output.log("People in /r/\#{SUB}:")
        for contributor in contributors
          List.output.log(" * \#{contributor}")
    """
  if(recipe_name == 'Sample: Gildings')
    $('#mmm-list-code').val """
      # Sample: Gildings
      # This recipe lists all of the people who have been gilded in
      # a particular subreddit. Using a limit (second parameter to the
      # 'gilded' method) is advisible when running on any subreddit that
      # is likely to have had a significant number of gildings!
      # This recipe also demonstrates a way of filtering the content
      # that is returned so as to least each name only once and to not
      # show any deleted accounts.

      SUB = 'MegaMegaMonitor'

      # Clear the output area
      List.output.clear()

      # Generate list of gilded content
      List.subreddit(SUB).gilded().then (gildings)->

        # Output the result
        List.output.log("People gilded in /r/\#{SUB}:")
        authors_seen = []
        for gilding in gildings
          author = gilding.data.author
          if(!authors_seen.includes(author) && author != '[deleted]')
            authors_seen.push author
            List.output.log(" * \#{author}")
    """
  if(recipe_name == 'Sample: Intersection')
    $('#mmm-list-code').val """
      # Sample: Intersection
      # This recipe lists the people who are in both of two subs. Fast Mode is recommended.
      # Naturally it requires that you have access to both subs!

      FIRST_SUB  = 'MagicSecrets'
      SECOND_SUB = 'The_Haven'

      # Clear the output area
      List.output.clear()

      # Generate lists
      List.subreddit(FIRST_SUB).contributors().then (first_sub_contribs)->
        List.subreddit(SECOND_SUB).contributors().then (second_sub_contribs)->
          intersection = (c for c in first_sub_contribs when c in second_sub_contribs)

          # Output the result
          List.output.log("People in both /r/\#{FIRST_SUB} and /r/\#{SECOND_SUB}:")
          for contributor in intersection
            List.output.log(" * \#{contributor}")
  """
  if(recipe_name == 'Sample: In One But Not Another')
    $('#mmm-list-code').val """
      # Sample: In One But Not Another
      # This recipe lists the people who are in the first of two subs but NOT in the second.
      # Coupled with an invitation tool, you could use it to mirror the membership of an existing
      # sub into your new sub.
      # It will work faster in Fast Mode, but if you care about your membership being bang-on
      # accurate (rather than being up to a day out-of-date) then you'll want to use Slow Mode.

      FIRST_SUB  = 'MegaLounge'
      SECOND_SUB = 'MegaMusicLounge'

      # Clear the output area
      List.output.clear()

      # Generate lists
      List.subreddit(FIRST_SUB).contributors().then (first_sub_contribs)->
        List.subreddit(SECOND_SUB).contributors().then (second_sub_contribs)->
          outersection = (c for c in first_sub_contribs when c not in second_sub_contribs)

          # Output the result
          List.output.log("People in /r/\#{FIRST_SUB} but not in /r/\#{SECOND_SUB}:")
          for contributor in outersection
            List.output.log(" * \#{contributor}")
  """
  if(recipe_name == 'Sample: Invite Contributors')
    $('#mmm-list-code').val """
      # Sample: Invite Contributors
      # This recipe invites each person in a static list into a sub that you moderate.
      # If you try to do more than about 100 people in an hour, this will probably silently
      # fail, because of Reddit limitations that MMM's Lists don't yet auto-detect.

      SUB                 = 'GildedTrees'
      INVITEES            = 'avapoet Greypo 10_9_'.split(/\\s+/)

      # Clear the output area
      List.output.clear()

      # Attempt to invite people
      # By the way - it's not just add_contributor: you can call any of:
      # * add_contributor
      # * remove_contributor
      # * ban
      # * unban
      # * mute
      # * unmute
      List.output.log("Inviting people to /r/\#{SUB}:")
      for contributor in INVITEES
        List.output.log(" * \#{contributor}")
        List.subreddit(SUB).add_contributor(contributor).then(null)
  """
  if(recipe_name == 'Sample: Invite Contributors From Another')
    $('#mmm-list-code').val """
      # Sample: Invite Contributors From Another
      # This recipe lists the people who are in the first of two subs but NOT in the second.
      # Then it invites each of those people into the second sub. You'll need appropriate
      # permissions, of course! To prevent from running up against Reddit limits, it will
      # only try to invite 100 people at a time: this seems to be the cap in a given hour.
      # You probably want Slow Mode for this.

      FIRST_SUB  = 'MegaLounge'
      SECOND_SUB = 'BestOf_MegaLounge'

      # Clear the output area
      List.output.clear()

      # Generate lists
      List.subreddit(FIRST_SUB).contributors().then (first_sub_contribs)->
        List.subreddit(SECOND_SUB).contributors().then (second_sub_contribs)->
          outersection = (c for c in first_sub_contribs when c not in second_sub_contribs)
          first_hundred       = outersection.slice 0, 100

          # Attempt to invite 100 people to the second sub
          List.output.log("Inviting people to /r/\#{SECOND_SUB}:")
          for contributor in first_hundred
            List.output.log(" * \#{contributor}")
            List.subreddit(SECOND_SUB).add_contributor(contributor).then(null)
  """
  if(recipe_name == 'Sample: Known Subs')
    $('#mmm-list-code').val """
      # Sample: Known Subs
      # This recipe lists all subs that you're a member of that are known to MegaMegaMonitor.
      # (Incidentally, these are the subs for which Fast Mode should make an appreciable difference!)
      # For a full list of MegaMegaMonitor-enhanced subs, see https://www.reddit.com/r/megamegamonitor/wiki/supported

      # Clear the output area
      List.output.clear()

      # Output the result
      List.output.log("MMM-enhanced subs of which you are a member:")
      for sub in List.known_subs()
        List.output.log(" * /r/\#{sub}")
  """
  if(recipe_name == 'Sample: MegaLounge Populations')
    $('#mmm-list-code').val """
      # Sample: MegaLounge Populations
      # This recipe lists the number of people in each known "chain" MegaLounge.

      # Run in Fast Mode (preferable for this script)
      List.mode 'fast'

      # Clear the output area
      List.output.clear()

      # For each MegaLounge ("chain") subreddit...
      List.chain_subreddits().forEach (sub)->

        # ...output the number of contributors and its name
        sub.contributors().then (contributors)->
          List.output.log "\#{contributors.length}\\t\#{sub.display_name}"
  """
  if(recipe_name == 'Sample: MMMers')
    $('#mmm-list-code').val """
      # Sample: MMMers
      # This recipe lists everybody who's recently used MegaMegaMonitor. Hey look: you're in there!

      List.output.clear()
      List.output.log("MMMers:")
      for contributor in List.mmm_users()
        List.output.log(" * \#{contributor}")
  """
  if(recipe_name == 'Sample: Smart Ascender')
    $('#mmm-list-code').val """
      # Sample: Smart Ascender
      # This advanced recipe combines the examples given in Sample: Gildings and
      # Sample: In One But Not Another. For a given set of defined 'ascension
      # paths', it looks for everybody who's been gilded in each 'from' sub
      # but who isn't a member of the corresponding 'to' sub.
      # For speed, it limits the number of pages worth
      # of gildings it looks at on each level. It can be run in fast mode
      # or slow mode, with the usual caveats: fast mode will be quicker;
      # slow mode will be more-thorough.
      # It doesn't automatically invite them to the higher sub. See
      # Sample: Invite Contributors for an example of this, and remember
      # to limit it to 100 at a time so as not to run up against Reddit limits.

      ASCENSIONS = [
        { from: 'MegaLounge', consider_pages: 2, to: 'MegaMegaLounge' },
        { from: 'MegaMegaLounge', consider_pages: 1, to: 'MegaMegaMegaLounge' },
        { from: 'MegaMegaMegaLounge', consider_pages: 1, to: 'MegaLoungeIV' }
      ]

      # A convenience-function to turn gildings into permalinks
      permalink = (gilding)->
        if gilding.kind == 't1' # comment
          "\#{gilding.data.link_permalink}#\#{gilding.data.id}"
        else if gilding.kind == 't3' # post
          "https://www.reddit.com\#{gilding.data.permalink}"

      # Clear the output area
      List.output.clear()

      # Function to loop through each ascension to check
      next_ascension = 0
      checkAnAscension = ->
        if ascension_path = ASCENSIONS[next_ascension]
          new Promise (resolve, reject)->
            List.output.log "Considering /r/\#{ascension_path.from} -> /r/\#{ascension_path.to}:"
            
            # Get list of people already on the upper level
            List.subreddit(ascension_path.to).contributors().then (already_ascended)->

              # Get recent gildings on the lower level
              authors_seen = []
              List.subreddit(ascension_path.from).gilded(undefined, (ascension_path.consider_pages - 1)).then (gildings)->
                for gilding in gildings
                  # Extract the author for each gilding and determine whether or not we've seen them yet
                  # (in case they've been multi-gilded at this level: we don't need to invite them twice!)
                  author = gilding.data.author
                  if(!authors_seen.includes(author) && author != '[deleted]')
                    authors_seen.push author
              
                    # Determine whether this author needs to ascend or whether they already have:
                    if !already_ascended.includes(author)
                      List.output.log(" * \#{author} can ascend from /r/\#{ascension_path.from} to /r/\#{ascension_path.to} for \#{permalink(gilding)}")            
                      
                # Finish: allows us to move on to the next ascension path to check
                resolve()

          .then ->
            # Move onto the next one, starting with a blank line to make the output look nicer
            List.output.log('')
            next_ascension = next_ascension + 1
            checkAnAscension()

      # Begin the process
      checkAnAscension()
  """
  if(recipe_name == 'Sample: XOR')
    $('#mmm-list-code').val """
      # Sample: XOR
      # This recipe lists the people who are in EXACTLY ONE of two subs (i.e. in one OR the other but not both!).
      # Fast Mode is recommended.
      # Naturally it requires that you have access to both subs!

      FIRST_SUB  = 'BestFriendClub'
      SECOND_SUB = 'decadeclub'

      # Clear the output area
      List.output.clear()

      # Generate lists
      List.subreddit(FIRST_SUB).contributors().then (first_sub_contribs)->
        List.subreddit(SECOND_SUB).contributors().then (second_sub_contribs)->
          xor_result          = (c for c in first_sub_contribs  when c not in second_sub_contribs).concat (c for c in second_sub_contribs when c not in first_sub_contribs)

          # Output the result
          List.output.log("People in /r/\#{FIRST_SUB} or /r/\#{SECOND_SUB} but not both:")
          for contributor in xor_result
            List.output.log(" * \#{contributor}")
  """
  # Force loaded recipe into CodeMirror visual editor
  window.mmm.temp.mmm_list_code_codemirror.setValue $('#mmm-list-code').val()

# Show the Start (welcome) page
show_start_page = ->
  window.mmm.temp.on_start_page = true
  $('.wikititle, .pageactions').remove()
  $('.wiki-page-content .wiki').html MMM_START_HTML
  if (returnToUrl = window.sessionStorage.getItem('mmm.returnToUrl') && returnToUrl && (returnToUrl != '')) # TODO: fix! Broken!
    window.sessionStorage.removeItem('mmm.returnToUrl')
    $('#return-to-url').html("<a href=\"#{returnToUrl}\">#{returnToUrl}</a>")
  else
    $('#return-to-url').closest('p').remove()

# Show the Map page
show_map_page = ->
  log 2, "Showing map page."
  $('.side, .footer-parent, .debuginfo').remove()
  $('.content').html """
    <style>body { background: url('https://e.thumbs.redditmedia.com/JeIvo2VCJadsC0DL.png'); }</style>
    <div class="megalounges-map">
      <div class="megalounges-map-title">
        <h1>Map of the MegaLounges</h1>
        <h2>(according to #{window.mmm.username}, #{(new Date()).toDateString()})</h2>
      </div>
      <div class="megalounges-map-content">
        <div class="megalounges-map-content-item megalounges-map-content-item-mystery">
          <h3>here be dragons</h3>
          <p>
            Population: ?
          </p>
        </div>
      </div>
    </div>
  """
  mapContent = $('.megalounges-map-content')
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    if sub.chain_number
      mapContent.append """
        <div class="megalounges-map-content-item-separator">
          &#x2191;
        </div>
        <div class="megalounges-map-content-item">
          <h3>#{sub.display_name}</h3>
          <p>
            Population: #{sub.users.length}
          </p>
        </div>
      """

# Show the Tails page
show_tails_page = ->
  log 2, "Showing tails page."
  $('.side, .footer-parent, .debuginfo').remove()
  $('.content').html """
    <style>body { background: url('https://e.thumbs.redditmedia.com/JeIvo2VCJadsC0DL.png'); }</style>
    <div class="megalounges-tails">
      <div class="megalounges-tails-title">
        <h1>MegaLounge Chain Tails</h1>
        <h2>(according to #{window.mmm.username}, #{(new Date()).toDateString()})</h2>
      </div>
      <ul class="megalounges-tails-content">
      </ul>
    </div>
  """
  tailsContent = $('.megalounges-tails-content')
  subs = []
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    subs.push sub if sub.chain_number
  for i in [0...(subs.length - 1)]
    this_sub = subs[i]
    sub_below = subs[i + 1]
    diff = sub_below.users.length - this_sub.users.length
    if diff > 0 && diff < 100
      missing_peeps = ""
      for peep in sub_below.users
        console.log peep[0]
        found = false
        for innerPeep in this_sub.users
          found = true if innerPeep[0] == peep[0]
        if !found
          missing_peeps += """
            <li><a href="/u/#{peep[0]}">#{peep[0]}</a></li>
          """
      tailsContent.append """
        <li class="megalounges-tails-content-item">
          #{diff} people are in <a href="/r/#{subs[i + 1].display_name}">#{subs[i + 1].display_name}</a> but not in <a href="/r/#{subs[i].display_name}">#{subs[i].display_name}</a>. They are:
          <ul>
            #{missing_peeps}
          </ul>
        </li>
      """
    else
      tailsContent.append """
        <li class="megalounges-tails-content-item">
          #{diff} people are in <a href="/r/#{subs[i + 1].display_name}">#{subs[i + 1].display_name}</a> but not in <a href="/r/#{subs[i].display_name}">#{subs[i].display_name}</a>.
        </li>
      """

# Show the Changes page
show_changes_page = ->
  log 2, "Showing changes page."
  $('.side, .footer-parent, .debuginfo').remove()
  $('.content').html """
    <style>body { background: url('https://e.thumbs.redditmedia.com/JeIvo2VCJadsC0DL.png'); }</style>
    <div class="megalounges-changes">
      <div class="megalounges-changes-title">
        <h1>Private Sub Changes</h1>
        <h2>(according to #{window.mmm.username}, #{(new Date()).toDateString()})</h2>
      </div>
      <ul class="megalounges-changes-content">
        Loading... please wait...
      </ul>
    </div>
  """
  $.get CHANGES_URL, { username: window.mmm.username, accesskey: window.mmm.users[window.mmm.username].accesskey }, (html)->
    $('.megalounges-changes-content').html html

# Show the Options page
show_options_page = ->
  log 2, "Showing options page."
  $('.side, .footer-parent, .debuginfo').remove()
  $('.content').html MMM_OPTIONS_HTML
  # Connect CodeMirror source code editor to the Lists recipe editor
  $('head').append '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.10.0/codemirror.min.css" />' # CodeMirror CSS
  window.mmm.temp.mmm_list_code_codemirror = CodeMirror.fromTextArea $('textarea#mmm-list-code')[0]
  # Populate the list of suppressable icons
  added_chain_sub_to_suppressable_list = false
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    if sub.chain_number
      # Icon for a MegaLounge
      if !added_chain_sub_to_suppressable_list
        $('#icon-suppression').append """
            <li>
              <label for="show-icon-mega">
                <input type="checkbox" id="show-icon-mega" data-setting="show-icon-mega" data-setting-default="1" />
                <span class=\"mmm-icon mmm-icon-#{sub.id}\"></span>
                MegaLounge-chain subs
              </label>
            </li>
          """
      added_chain_sub_to_suppressable_list = true
    else if sub.id == -1
      # Icon for Uses MegaMegaMonitor
      $('#icon-suppression').append """
          <li>
            <label for="show-icon-#{sub.id}">
              <input type="checkbox" id="show-icon-#{sub.id}" data-setting="show-icon-#{sub.id}" data-setting-default="1" />
              <span class=\"mmm-icon mmm-icon-#{sub.id}\"></span>
              MegaMegaMonitor users (including "super special" users)
            </label>
          </li>
        """
    else
      $('#icon-suppression').append """
          <li>
            <label for="show-icon-#{sub.id}">
              <input type="checkbox" id="show-icon-#{sub.id}" data-setting="show-icon-#{sub.id}" data-setting-default="1" />
              <span class=\"mmm-icon mmm-icon-#{sub.id}\"></span>
              #{sub.display_name}
            </label>
          </li>
        """
  # Populate list of encryption keys
  if !window.mmm.temp.crypto_options
    window.mmm.temp.crypto_options = []
    for sub in window.mmm.users[window.mmm.username].icons.data.subs
      if (sub.cryptokeys || []).length > 0
        sub_name = if (sub.id == -1) then 'Anyone using MegaMegaMonitor' else sub.display_name
        window.mmm.temp.crypto_options.push "<option value=\"#{sub.cryptokeys[0][0]}\" data-key=\"#{sub.cryptokeys[0][1]}\">#{sub_name}</option>"
  $('#mmm-static-crypto-crypto-key').html(window.mmm.temp.crypto_options.join(''))
  # Options page - sections menu
  $('#mmm-options-sections li').on 'click', ->
    $('.mmm-options-section, #mmm-options-sections li').removeClass('current')
    $(".mmm-options-section[data-section='#{$(this).data('section')}']").addClass('current')
    $(this).addClass('current')
    false
  $('#mmm-options-sections li:first').trigger 'click'
  if DEBUG_MODE then $("#mmm-options-sections li[data-section='debug']").show()
  # Options page - general-purpose settings
  window.mmm.users[window.mmm.username].settings ?= {}
  $('[data-setting]').each ->
    setting_name = $(this).data('setting')
    setting_value = window.mmm.users[window.mmm.username].settings[setting_name] || ''
    log 2, "Loading options setting '#{setting_name}' with value '#{setting_value}'"
    if($(this).is(':checkbox'))
      if setting_value == ''
        setting_value = ($(this).data('setting-default') || -1)
        log 2, "(falling back on checkbox default of '#{setting_value}')"
      $(this).prop('checked', (parseInt(setting_value) == 1))
    else
      $(this).val(setting_value)
  .on 'change', ->
    setting_name = $(this).data('setting')
    if($(this).is(':checkbox'))
      if $(this).is(':checked')
        log 2, "Checked options setting checkbox '#{setting_name}'"
        window.mmm.users[window.mmm.username].settings[setting_name] = 1
      else
        log 2, "Unhecked options setting checkbox '#{setting_name}'"
        window.mmm.users[window.mmm.username].settings[setting_name] = -1
    else
      log 2, "Changed setting '#{setting_name}' to #{$(this).val()}"
      window.mmm.users[window.mmm.username].settings[setting_name] = $(this).val()
    save_offline_data()

  # Options page - icons section
  $('#icon-size').on 'change', ->
    # update sample icon when icon size changed, using same mechanic as actually used
    $(this).find('option').each ->
      $('body').removeClass $(this).val()
    $('body').addClass $(this).find('option:selected').val()

  # Options page - lists section
  $('#mmm-list-mode').text List.mode()
  $('#mmm-list-mode-change').on 'click', ->
    List.toggle_mode()
    false
  load_recipe_book()
  $('#mmm-list-recipebook').on 'change', ->
    load_recipe($(this).val())
  $('#save-recipe').on 'click', ->
    name = prompt 'Name for recipe file?', $('#mmm-list-recipebook').val()
    if name.match(/^Sample:/) then return alert "Cannot save personal recipes with 'Sample:' prefix."
    if (window.mmm.recipes ?= {})[name]
      unless confirm('Recipe with this name already exists. Overwrite?') then return
    window.mmm.temp.mmm_list_code_codemirror.save()
    window.mmm.recipes[name] = $('#mmm-list-code').val()
    save_offline_data()
    load_recipe_book()
    $('#mmm-list-recipebook').val(name) # select just-saved recipe
  $('#delete-recipe').on 'click', ->
    if ((name = $('#mmm-list-recipebook').val()) == '') then return alert 'No recipe selected.'
    if name.match(/^Sample:/) then return alert "Cannot delete recipes with 'Sample:' prefix."
    unless confirm('Really delete this recipe?') then return
    delete (window.mmm.recipes ?= {})[name]
    save_offline_data()
    load_recipe_book()
  $('#mmm-list-execute').on 'click', ->
    $(this).prop 'disabled', true
    log 2, "Executing list script."
    window.mmm.temp.mmm_list_code_codemirror.save()
    srcCode = """
      #{MMM_LISTS_JS}
      self.onmessage = function(e){
        if(e.data[0] == 'begin') { // received 'begin' message
          List.set_subs(JSON.parse(e.data[1])); // record subs data
          List.mode(e.data[2]); // set mode
          try {
            #{CoffeeScript.compile($('#mmm-list-code').val(), { bare: true })}
          } catch (error) {
            List.output.log('ERROR: ' + error);
          } finally {
            self.postMessage("$('#mmm-list-execute').prop('disabled', false)"); // re-enable the button
          }
        }
      }
    """
    #console.log srcCode
    blob = new Blob([srcCode], { type: "text/javascript" })
    workerUrl = window.URL.createObjectURL(blob)
    #console.log("registering worker from #{workerUrl}")
    worker = new Worker(workerUrl)
    worker.onmessage = (e) -> # expects code to eval
      #console.log "Received from Worker: #{e.data}"
      eval e.data
    worker.postMessage(['begin', JSON.stringify(window.mmm.users[window.mmm.username].icons.data.subs), $('#mmm-list-mode').text()]);

  # Options page - crypto section
  $('#mmm-static-crypto-encrypt').on 'click', ->
    select = $('#mmm-static-crypto-crypto-key')
    key_id = select.val()
    key = select.find('option:selected').data('key')
    $('#mmm-static-crypto-result-output').val(encrypt($('#mmm-static-crypto-secret-message').val(), $('#mmm-static-crypto-public-message').val(), key_id, key));
    $('#mmm-static-crypto-result').show();

  # Options page - troubleshooting section
  $('#mmm-troubleshooting-check-plugin').on 'click', check_for_update_to_plugin
  $('#mmm-troubleshooting-check-data').on 'click', check_for_update_to_data
  $('#mmm-troubleshooting-clear-data').on 'click', ->
    if confirm("MegaMegaMonitor is about to forget everything it knows about you and reset to its factory settings!")
      clear_all_offline_data()

# Forces the page to update on the next check - useful if e.g. fresh data has been downloaded that might invalidate current data
force_page_to_require_update = ->
  window.mmm.temp.sitetable.find('.mmm-author-icons').remove()
  window.mmm.temp.sitetable.find('.author.mmm-ran').removeClass('mmm-ran')
  #TODO: something with a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]'] ?
  #TODO: something with textareas?

# Updates page with icons, decryption, etc.
update_page = ->
  # If needed, inject data-specific CSS into stylesheet
  if !window.mmm.data_css_injected
    log 2, "Injecting data CSS."
    css = window.mmm.users[window.mmm.username].icons.data.css

    # Append CSS to hide suppressed icons
    window.mmm.users[window.mmm.username].settings ?= {}
    suppressed_sub_icons = []
    chain_subs_are_suppressed = (window.mmm.users[window.mmm.username].settings['show-icon-mega'] == -1)
    for sub in window.mmm.users[window.mmm.username].icons.data.subs
      if (sub.chain_number && chain_subs_are_suppressed) || (window.mmm.users[window.mmm.username].settings["show-icon-#{sub.id}"] == -1)
        # sub is suppressed - add some CSS
        suppressed_sub_icons.push ".tagline .mmm-icon.mmm-icon-#{sub.id}"
    if suppressed_sub_icons.length > 0
      icon_suppression_css = "#{suppressed_sub_icons.join(',')}{display:none;}"
      log 2, "Injecting icon suppression CSS: #{icon_suppression_css}"
      css += icon_suppression_css
    # Add the CSS to the page
    $('#mmm-css-block').after("<style type=\"text/css\" id=\"mmm-data-css-block\">#{css}</style>")

    # Set up IntersectionObserver
    IntersectionObserver.prototype.POLL_INTERVAL = parseInt(window.mmm.users[window.mmm.username].settings['update-page-frequency'] || '500')
    window.mmm.authorObserver = new IntersectionObserver(authorsObserved, { rootMargin: '200px' });
    window.mmm.cryptoObserver = new IntersectionObserver(cryptosObserved, { rootMargin: '200px' });
    window.mmm.usertextObserver = new IntersectionObserver(usertextsObserved, { rootMargin: '200px' });

    # Mark these actions as done so they're not done again
    window.mmm.data_css_injected = true

  # Tie the IntersectionObservers to anything that they're not already tied to, but need to be
  authorsToObserve = window.mmm.temp.sitetable.find('.author:not(.mmm-observed)')
  authorsToObserve.each ->
    window.mmm.authorObserver.observe(this)
  authorsToObserve.addClass 'mmm-observed'
  cryptosToObserve = window.mmm.temp.sitetable.find('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]:not(.mmm-observed)')
  cryptosToObserve.each ->
    window.mmm.cryptoObserver.observe(this)
  cryptosToObserve.addClass 'mmm-observed'
  usertextsToObserve = window.mmm.temp.sitetable.find(".usertext textarea:not('.mmm-observed'), .usertext-edit textarea:not('.mmm-observed')")
  usertextsToObserve.each ->
    window.mmm.usertextObserver.observe(this)
  usertextsToObserve.addClass 'mmm-observed'

  # Trigger this again in a bit
  setTimeout update_page, parseInt(window.mmm.users[window.mmm.username].settings['update-page-frequency'] || '500')

authorObserved = (author, observer) ->
  elem = $(author.target)
  observer.unobserve(elem[0]) # stop watching this author for future changes
  elem.addClass 'mmm-ran'
  if (href = elem.attr('href'))
    username = href.split('/').pop()
    elem.after(icon_html_for_user(username))

authorsObserved = (authors, observer) ->
  authorObserved(author, observer) for author in authors
  save_offline_data() # in case any icon sets were precached as a result of this observation

cryptoObserved = (crypto, observer) ->
  elem = $(crypto.target)
  observer.unobserve(elem[0]) # stop watching this crypto for future changes
  attempt_to_decrypt elem

cryptosObserved = (cryptos, observer) ->
  cryptoObserved(crypto, observer) for crypto in cryptos

usertextObserved = (usertext, observer) ->
  elem = $(usertext.target)
  observer.unobserve(elem[0]) # stop watching this usertext for future changes
  add_textarea_options_to elem

usertextsObserved = (usertexts, observer) ->
  usertextObserved(usertext, observer) for usertext in usertexts

# Returns the accesskey for the given username, if available; null otherwise
accesskey_for = (username)->
  log 2, "Looking up accesskey for user #{username}."
  return null if !window.mmm.users[username] || !window.mmm.users[username].accesskey
  window.mmm.users[username].accesskey

# Load specified offline data (returns null if not found in offline data store)
load_offline_data = (key)->
  log 2, "Loading offline data: #{key}"
  if loadedData = window.localStorage.getItem("mmm.#{key}")
    return JSON.parse(loadedData)
  else
    return null

# Save offline data
save_offline_data = ->
  log 2, "Saving offline data."
  window.localStorage.setItem('mmm.users', JSON.stringify(window.mmm.users))
  window.localStorage.setItem('mmm.recipes', JSON.stringify(window.mmm.recipes))

##########################################################################
### Advertise to log that script is loaded                             ###
##########################################################################

log 2, "MMM script loaded. on_reddit_com=#{if on_reddit_com() then 'true' else 'false'}."

##########################################################################
### Load offline data                                                  ###
##########################################################################

window.mmm.users = load_offline_data('users') || window.mmm.users
window.mmm.recipes = load_offline_data('recipes') || window.mmm.recipes || {}

##########################################################################
### Authentication provision                                           ###
##########################################################################

if on_reddit_com()
  # Automatically authorise our way through the warning page. Yes, really.
  if $(".oauth2-authorize form[action='/api/v1/authorize'] input:hidden[value='#{REDDIT_APP_CLIENT_ID}']").length > 0
    log 2, "Auto-clicking 'Authorise' button."
    $('body').hide()
    $('input:submit.allow').click()

  # Check for a secret key being provided to us by the MMM server.
  if on_options_page() && (matches = window.location.search.match(/^\?setaccessuser=(.*)&setaccesskey=(.*)$/))
    window.mmm.users[matches[1]] ?= {}
    window.mmm.users[matches[1]].accesskey = matches[2]
    log 2, "Creating accesskey pair: #{matches[1]} = #{matches[2]}"
    save_offline_data()
    # Show "start page" if we're REALLY new (no data yet!), otherwise redirect
    if !window.mmm.users[matches[1]].icons
      show_start_page()
    else 
      if (returnToUrl = window.sessionStorage.getItem('mmm.returnToUrl'))
        window.sessionStorage.removeItem('mmm.returnToUrl')
        window.location.href = returnToUrl
      else
        window.location.href = '/'

##########################################################################
### Plugin loader                                                      ###
##########################################################################

if on_reddit_com()
  # Launch MegaMegaMonitor
  log 2, "Calling /api/me.json to determine logged-in identity."
  $.getJSON '/api/me.json', (json)->
    if json.data && json.data.name
      window.mmm.username = json.data.name
      # Set identity string and, if specified, impersonation request
      window.mmm.users[window.mmm.username] ?= {}
      window.mmm.users[window.mmm.username].settings ?= {}
      window.mmm.users[window.mmm.username].settings['impersonate'] ?= ''
      window.mmm.users[window.mmm.username].settings['impersonate-accesskey'] ?= ''
      if (window.mmm.users[window.mmm.username].settings['impersonate'] != '') && (window.mmm.users[window.mmm.username].settings['impersonate-accesskey'] != '')
        original_username = window.mmm.username
        impersonate = window.mmm.users[window.mmm.username].settings['impersonate']
        impersonate_accesskey = window.mmm.users[window.mmm.username].settings['impersonate-accesskey']
        log 2, "Attempting to impersonate '#{impersonate}'"
        window.mmm.username = impersonate
        window.mmm.users[impersonate] ?= {}
        window.mmm.users[impersonate].accesskey = impersonate_accesskey
        $('#header-bottom-right .user > *').wrap('<strike></strike>').closest('.user').prepend("<a href=\"https://www.reddit.com/user/#{impersonate}/\">#{impersonate}</a>&nbsp;").append("&nbsp;[<a href=\"#\" class=\"mmm-end-impersonation\" data-original-username=\"#{original_username}\">end impersonation</a>]")
        $('.mmm-end-impersonation').click ->
          original_username = $(this).data('original-username')
          window.mmm.users[original_username].settings['impersonate'] = ''
          window.mmm.users[original_username].settings['impersonate-accesskey'] = ''
          save_offline_data()
          window.location.reload()
          false
  .then ->
    log 2, "Setting up MMM."
    add_head_scripts()
    add_event_handlers()
    add_mmm_icon()
    add_megalounge_dropdown()

    if window.mmm.username
      log 9, "Logged in to Reddit as #{window.mmm.username}."
      if accesskey_for(window.mmm.username)
        # Logged in and holding an accesskey
        log 2, "Holding an accesskey (#{window.mmm.users[window.mmm.username].accesskey})."
        # Add actions to the MMM popup bubble and inject settings into the page
        add_actions_to_mmm_bubble()
        window.mmm.users[window.mmm.username].settings ?= {}
        $('body').addClass(window.mmm.users[window.mmm.username].settings['icon-size'] || '')
        # Check if we have data AT ALL - if so, use it to update the page
        if i_have_icon_data()
          log 2, "Offline data present: updating page."
          update_page()
        # Check if icons are outdated and update if necessary, then update the page (again, if already done above)
        if icons_outdated()
          log 2, "Icon data is outdated: updating."
          $.when(update_icons()).then ->
            force_page_to_require_update()
            update_page()

        # Handle Options Page
        if on_options_page()
          show_options_page()

        # Handle Map Page
        if on_map_page()
          show_map_page()

        # Handle Tails Page
        if on_tails_page()
          show_tails_page()

        # Handle Changes Page
        if on_changes_page()
          show_changes_page()

      else
        #console.log window.mmm.username
        #console.log window.mmm.users[window.mmm.username]
        # Don't have an accesskey for the current user: request that the user accept one.
        log 2, "Showing 'allow/decline' bubble."
        $('#mmm-status').html """
          <p>To function, <strong>MegaMegaMonitor</strong> needs to know your reddit username. Permit this?</p>
          <p>
            <a class="fancybutton allow" id="mmm-authorize-allow" href="#{AUTH_URL}">Allow</a>
            <a class="fancybutton decline" id="mmm-authorize-decline" href="#">Decline</a>
          </p>
        """
        $('#mmm-authorize-allow').click ->
          window.sessionStorage.setItem('mmm.returnToUrl', window.location.href)
        $('#mmm-authorize-decline').click ->
          $('#mmm-help').fadeOut()
          false
        show_mmm_bubble()
    else
      log 9, "Log in to Reddit to use MegaMegaMonitor."

# Output MMM var to console (if debugging) for inspection purposes
# console.log window.mmm
