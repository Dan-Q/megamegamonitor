# set up jQuery
@$ = @jQuery = jQuery.noConflict(true)

# Set up MMM container on window
window.mmm = {
  log: [],    # log storage (this page load only, possibly mirrored to console)
  users: {},  # permanent storage space (retained between page loads)
  temp: {}    # temporary storage space (this page load only)
}

# Precache commonly-used jQuery resources
window.mmm.temp.body ||= $('body')
window.mmm.temp.sitetable ||= $('.sitetable, .wiki-page-content, .commentarea, #newlink')

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
### List functions                                                     ###
##########################################################################

List =
  _mode: 'fast'

  # Waits 2 seconds to throttle requests to the Reddit API
  tarpit: (ms = 2000)->
    now = new Date().getTime()
    finish = now + ms
    while(finish > now)
      now = new Date().getTime()

  mode: (val)->
    if (val == 'fast') || (val == 'slow') # setting
      this._mode = val
      $('#mmm-list-mode').text(val)
    else                                  # getting
      this._mode

  toggle_mode: ->
    this.mode(if (this.mode() == 'fast') then 'slow' else 'fast')

  output:
    clear: ->
      $('#mmm-list-output').val('')
    log: (text)->
      $('#mmm-list-output').val("#{$('#mmm-list-output').val()}#{text}\n")

  known_subs: ->
    (sub.display_name for sub in window.mmm.users[window.mmm.username].icons.data.subs when sub.id > 0)

  mmm_users: ->
    List.subreddit((sub.display_name for sub in window.mmm.users[window.mmm.username].icons.data.subs when sub.id > 0)[0]).contributors()

  chain_subreddits: ->
    (List.subreddit(sub.display_name) for sub in window.mmm.users[window.mmm.username].icons.data.subs when sub.chain_number)

  subreddit: (subreddit_display_name)->
    display_name: subreddit_display_name

    contributors: (progress_callback)->
      fast_mode_sub = (sub for sub in window.mmm.users[window.mmm.username].icons.data.subs when sub.display_name.toLowerCase() is subreddit_display_name.toLowerCase())[0]
      if (List.mode() == 'fast') && fast_mode_sub
        log 2, "Fast-fetching contributors for /r/#{subreddit_display_name}."
        (user[0] for user in fast_mode_sub.users)
      else
        log 2, "Slow-fetching contributors for /r/#{subreddit_display_name}."
        # Fetch data
        after = ''
        results = []
        pages = 0
        root_url = "/r/#{subreddit_display_name}/about/contributors.json"
        log 2, "Slow-fetch: root URL is #{root_url}"
        while after != null # there's still more to fetch
          List.tarpit()
          url = "#{root_url}?limit=100&after=#{after}"
          log 2, "Slow-fetch: GET #{url}"
          $.ajax url,
            async: false # TODO: make this work asynchronously again so that browsers are happier
            dataType: 'json'
            success: (json, textStatus, jqXHR)->
              after = json.data.after
              json.data.children.forEach (child)->
                if child.name != '[deleted]'
                  results.push(child.name)
        # Return results
        log 2, "Done slow-fetching contributors for /r/#{subreddit_display_name}."
        results

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
  window.mmm.users[window.mmm.username].icons.data.cached ||= { users: {}, ciphers: {} } # set up space for caching e.g. icon HTML for each user
  if (cached_copy = window.mmm.users[window.mmm.username].icons.data.cached.users[username]) then return cached_copy
  log 2, "Generating icons for #{username}."
  icon_html_set = []
  found_chain_sub = false
  for sub in window.mmm.users[window.mmm.username].icons.data.subs
    if sub.users # only deal with subs that actually have users
      if !found_chain_sub || !sub.chain_number? # only consider adding an icon if we've not yet found a chain sub or this is not a chain sub: prevents duplicate chain icons
        log 2, " > Looking in #{sub.display_name}."
        user_data = sub.users.first (user_data)->
          user_data[0] == username
        if user_data
          log 2, " > > Found them!"
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
  save_offline_data()
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
  # Sample recipe - MegaLounge Populations
  $('#mmm-list-recipebook').append "<option>Sample: Contributors</option>"
  $('#mmm-list-recipebook').append "<option>Sample: Intersection</option>"
  $('#mmm-list-recipebook').append "<option>Sample: In One But Not Another</option>"
  $('#mmm-list-recipebook').append "<option>Sample: Known Subs</option>"
  $('#mmm-list-recipebook').append "<option>Sample: MegaLounge Populations</option>"
  $('#mmm-list-recipebook').append "<option>Sample: MMMers</option>"
  $('#mmm-list-recipebook').append "<option>Sample: XOR</option>"

# Loads a specified recipe from the book, given its name
load_recipe = (recipe_name)->
  log 2, "Loading recipe: #{recipe_name}"
  if(recipe_name == 'Sample: Contributors')
    $('#mmm-list-code').val """
      # Sample: Contributors
      # This recipe lists the people who are in a particular private sub
      # (so long as you have access to that sub).

      SUB = 'MegaLounge'

      # Clear the output area
      List.output.clear()

      # Generate lists
      contributors = List.subreddit(SUB).contributors()

      # Output the result
      List.output.clear()
      List.output.log("People in \#{SUB}:\\n")
      for contributor in contributors
        List.output.log(" * \#{contributor}")
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
      first_sub_contribs  =  List.subreddit(FIRST_SUB).contributors()
      second_sub_contribs = List.subreddit(SECOND_SUB).contributors()
      intersection        = (c for c in first_sub_contribs when c in second_sub_contribs)

      # Output the result
      List.output.log("People in both \#{FIRST_SUB} and \#{SECOND_SUB}:\\n")
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
      first_sub_contribs  =  List.subreddit(FIRST_SUB).contributors()
      second_sub_contribs = List.subreddit(SECOND_SUB).contributors()
      outersection        = (c for c in first_sub_contribs when c not in second_sub_contribs)

      # Output the result
      List.output.log("People in \#{FIRST_SUB} but not in \#{SECOND_SUB}:\\n")
      for contributor in outersection
        List.output.log(" * \#{contributor}")
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
      List.output.log("MMM-enhanced subs of which you are a member:\\n")
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
        List.output.log "\#{sub.contributors().length}\t\#{sub.display_name}"
  """
  if(recipe_name == 'Sample: MMMers')
    $('#mmm-list-code').val """
      # Sample: MMMers
      # This recipe lists everybody who's recently used MegaMegaMonitor. Hey look: you're in there!

      List.output.clear()
      List.output.log("MMMers:\\n")
      for contributor in List.mmm_users()
        List.output.log(" * \#{contributor}")
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
      first_sub_contribs  =  List.subreddit(FIRST_SUB).contributors()
      second_sub_contribs = List.subreddit(SECOND_SUB).contributors()
      xor_result          = (c for c in first_sub_contribs  when c not in second_sub_contribs).concat (c for c in second_sub_contribs when c not in first_sub_contribs)

      # Output the result
      List.output.log("People in \#{FIRST_SUB} or \#{SECOND_SUB} but not both:\\n")
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
  window.mmm.users[window.mmm.username].settings ||= {}
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
  $('#mmm-list-execute').on 'click', ->
    $(this).prop 'disabled', true
    log 2, "Executing list script."
    window.mmm.temp.mmm_list_code_codemirror.save()
    try
      eval CoffeeScript.compile($('#mmm-list-code').val(), { bare: true }) # Note use of eval (rather than .run) and bare setting: both are required for this to work in scope!
    catch err
      alert err
    $(this).prop 'disabled', false

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

# Returns true if there are un-icon'd names (that need iconing), undecrypted messages (that need decrypting), etc.
# False otherwise.
page_requires_update = ->
  log 2, "Checking if page requires an update." # DEBUG
  # check for un-icon'd names and undecrypted messages
  if (window.mmm.temp.sitetable.find('.author:not(.mmm-ran), a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]:not(.mmm-ran)').length > 0) then return true
  if (window.mmm.temp.sitetable.find(".usertext textarea:not('.mmm-ran'), .usertext-edit textarea:not('.mmm-ran')").length > 0) then return true
  false

# Updates page with icons, decryption, etc.
update_page = ->
  # If needed, inject data-specific CSS into stylesheet
  if !window.mmm.data_css_injected
    log 2, "Injecting data CSS."
    css = window.mmm.users[window.mmm.username].icons.data.css
    # Append CSS to hide suppressed icons
    window.mmm.users[window.mmm.username].settings ||= {}
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
    window.mmm.data_css_injected = true
  # Check if page requires update, and update if necessary
  if page_requires_update()
    log 9, "Updating page..."
    # Find users who need icons, and add them
    window.mmm.temp.sitetable.find('.author:not(.mmm-ran)').each ->
      elem = $(this)
      if (href = elem.attr('href'))
        username = href.split('/').pop()
        elem.after(icon_html_for_user(username))
      elem.addClass('mmm-ran')
    # Find ciphertext that needs decrypting
    window.mmm.temp.sitetable.find('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]:not(.mmm-ran)').each ->
      attempt_to_decrypt $(this)
    # Find textareas that need tools adding
    window.mmm.temp.sitetable.find(".usertext textarea:not('.mmm-ran'), .usertext-edit textarea:not('.mmm-ran')").each ->
      add_textarea_options_to $(this)
    log 9, "Running as normal."
  setTimeout update_page, parseInt(window.mmm.users[window.mmm.username].settings['update-page-frequency'] || '2500')

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

##########################################################################
### Advertise to log that script is loaded                             ###
##########################################################################

log 2, "MMM script loaded. on_reddit_com=#{if on_reddit_com() then 'true' else 'false'}."

##########################################################################
### Load offline data                                                  ###
##########################################################################

window.mmm.users = load_offline_data('users') || window.mmm.users

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
    window.mmm.users[matches[1]] ||= {}
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
      window.mmm.users[window.mmm.username] ||= {}
      window.mmm.users[window.mmm.username].settings ||= {}
      window.mmm.users[window.mmm.username].settings['impersonate'] ||= ''
      window.mmm.users[window.mmm.username].settings['impersonate-accesskey'] ||= ''
      if (window.mmm.users[window.mmm.username].settings['impersonate'] != '') && (window.mmm.users[window.mmm.username].settings['impersonate-accesskey'] != '')
        original_username = window.mmm.username
        impersonate = window.mmm.users[window.mmm.username].settings['impersonate']
        impersonate_accesskey = window.mmm.users[window.mmm.username].settings['impersonate-accesskey']
        log 2, "Attempting to impersonate '#{impersonate}'"
        window.mmm.username = impersonate
        window.mmm.users[impersonate] ||= {}
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

    if window.mmm.username
      log 9, "Logged in to Reddit as #{window.mmm.username}."
      if accesskey_for(window.mmm.username)
        # Logged in and holding an accesskey
        log 2, "Holding an accesskey (#{window.mmm.users[window.mmm.username].accesskey})."
        # Add actions to the MMM popup bubble and inject settings into the page
        add_actions_to_mmm_bubble()
        window.mmm.users[window.mmm.username].settings ||= {}
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

###

# load data from data store, if available
lastVersion = JSON.parse(GM_getValue('version', VERSION))
accesskeys = JSON.parse(GM_getValue('accesskeys', '{}'))
iconsize = GM_getValue('iconsize', 'reg')
GM_setValue 'version', VERSION
userData = null
lastUpdated = 0

# Logger
log = (message)->
  console.log "MegaMegaMonitor: #{message}"

# define methods
mmmGetNinjaPirateVisibility = ->
  GM_xmlhttpRequest
    method: 'GET'
    url: '/api/me.json'
    onload: (npvresp1) ->
      username = JSON.parse(npvresp1.responseText).data.name
      url = 'https://www.megamegamonitor.com/ninja_pirate_visible.php'
      data = "version=#{VERSION}&username=#{username}&accesskey=#{accesskeys[username]}"
      log "POST #{url} #{data}"
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (npvresp2) ->
          log npvresp2.responseText
          if(npvresp2.responseText == '0')
            $('.mmm-ninja-pirate-status').html 'You are currently <strong>hidden</strong> from the enemy (you are still visible to your friends). This is the default. <a href="#" class="mmm-change-ninja-pirate-visibility" data-change-to="1">Come out of hiding?</a>'
          else if(npvresp2.responseText == '1')
            $('.mmm-ninja-pirate-status').html 'You are currently <strong>visible</strong> to the enemy. <a href="#" class="mmm-change-ninja-pirate-visibility" data-change-to="0">Go back into hiding?</a>'
          else
            $('.mmm-ninja-pirate-status').text npvresp2.responseText
          $('.mmm-change-ninja-pirate-visibility').click ->
            mmmChangeNinjaPirateVisibility $(this).data('change-to')

mmmChangeNinjaPirateVisibility = (visible)->
  GM_xmlhttpRequest
    method: 'GET'
    url: '/api/me.json'
    onload: (npvresp1) ->
      username = JSON.parse(npvresp1.responseText).data.name
      url = 'https://www.megamegamonitor.com/ninja_pirate_visible.php'
      data = "version=#{VERSION}&username=#{username}&accesskey=#{accesskeys[username]}&v=#{visible ? 1 : 0}"
      log "POST #{url} #{data}"
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (npvresp2) ->
          log 'MegaMegaMonitor Debug: mmmChangeNinjaPirateVisibility() - response received'
          mmmGetNinjaPirateVisibility()
          alert(npvresp2.responseText)

mmmOptions = ->
  # set URL using pushState
  history.pushState {}, "MegaMegaMonitor Options/Tools", "/r/MegaMegaMonitor/wiki/options"
  window.onpopstate = ->
    if(window.location.pathname == "/r/MegaMegaMonitor/wiki/options")
      window.history.back()
    else
      window.location.reload()
  # load style and content
  $('link[rel="stylesheet"], style:not(#mmm-css-block)').remove()
  $('head').append '<link href="//d1wjam29zgrnhb.cloudfront.net/css/combined2.css" rel="stylesheet">'
  $('body').html '{{j(snippets["mmm-options"])}}'
  # make "back to reddit" link work
  $('a[href="#back-to-reddit"]').click ->
    window.history.back()
    false
  # show appropriate iconsize setting
  $('#mmm-iconsize').val(iconsize).on 'change click keyup', ->
    iconsize = $('#mmm-iconsize').val()
    GM_setValue 'iconsize', iconsize
  # list "hidden" subs
  i_am_a_pirate = false
  i_am_a_ninja = false
  $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-mmm\" data-id=\"mmm\"> <label for=\"mmm-options-hidden-subs-mmm\"><span class=\"mmm-icon mmm-icon-64\"></span> MegaMegaMonitor users</label></li>")
  highest_megalounge_chain_number = -1
  highest_megalounge_chain_name = ''
  highest_megalounge_spriteset_position = -1
  userData.mySubreddits.forEach (sub) ->
    log "MegaMegaMonitor Debug: enumerating #{sub.display_name}"
    i_am_a_ninja = true if sub.display_name == 'NinjaLounge'
    i_am_a_pirate = true if sub.display_name == 'PirateLounge'
    if sub.chain_number
      if sub.chain_number > highest_megalounge_chain_number
        highest_megalounge_chain_number = sub.chain_number
        highest_megalounge_chain_name = sub.display_name
        highest_megalounge_spriteset_position = sub.spriteset_position
    else
      $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-#{sub.id}\" data-id=\"#{sub.id}\"> <label for=\"mmm-options-hidden-subs-#{sub.id}\"><span class=\"mmm-icon mmm-icon-#{sub.spriteset_position}\"></span> #{sub.display_name}</label></li>")
  if highest_megalounge_chain_number > -1
    $('#mmm-options-hidden-subs').append("<li><input type=\"checkbox\" id=\"mmm-options-hidden-subs-chain\" data-id=\"chain\"> <label for=\"mmm-options-hidden-subs-chain\"><span class=\"mmm-icon mmm-icon-#{highest_megalounge_spriteset_position}\"></span> MegaLounge chain</label></li>")
  # set initial values of checkboxes
  #log "MegaMegaMonitor Debug: working with suppressionList = #{JSON.stringify(suppressionList)}"
  suppressionList.forEach (id)->
    $("#mmm-options-hidden-subs-#{id}").prop('checked', true)
  # allow changing of "hidden" subs
  $('#mmm-options-hidden-subs input:checkbox').on 'click', ->
    suppressionList = $('#mmm-options-hidden-subs input:checkbox:checked').map ->
      $(this).data 'id'
    .toArray()
    log "MegaMegaMonitor Debug: writing suppressionList = #{JSON.stringify(suppressionList)}"
    GM_setValue 'suppressionList', JSON.stringify(suppressionList)
  # show/hide ninja/pirate sections (variables were set while processing hidden subs, above)
  $('#mmm-options').addClass('mmm-i-am-a-ninja') if i_am_a_ninja
  $('#mmm-options').addClass('mmm-i-am-a-pirate') if i_am_a_pirate
  mmmGetNinjaPirateVisibility() if i_am_a_ninja || i_am_a_pirate
  # allow submission of 'search' form
  $('#mmm-tools-find-comment-submit').click ->
    window.mmm_tools_find_comment_username = $('#mmm-tools-find-comment-username').val()
    window.mmm_tools_find_comment_subreddit = $('#mmm-tools-find-comment-subreddit').val().toLowerCase()
    window.mmm_tools_find_comment_type = $('#mmm-tools-find-comment-type').val()
    window.mmm_tools_find_comment_after = ''
    window.mmm_tools_find_comment_scanned = 0
    window.mmm_tools_find_comment_cancel = false
    $('body').html '{{j(snippets["mmm-searching"])}}'
    $('a[href="#back-to-reddit"]').click ->
      window.location.reload()
      false
    $('#mmm-search-cancel').click ->
      window.mmm_tools_find_comment_cancel = true
      false
    mmmToolsFind()
    false
  # Allow submission of 'gilding graphs' request
  $('#mmm-tools-gilding-graphs-submit').on 'click', ->
    my_gildings_given_json = []
    mmm_gg_l = (mmm_gg_n, mmm_gg_i) ->
      mmm_gg_t = '/u/' + mmm_gg_n + '/gilded/given.json?limit=100&after=' + mmm_gg_i
      $('#mmm_gg_d').append('.')
      $.getJSON mmm_gg_t, (mmm_gg_i) ->
        my_gildings_given_json.push(mmm_gg_i.data.children)
        if null != mmm_gg_i.data.after
          setTimeout ->
            mmm_gg_l mmm_gg_n, mmm_gg_i.data.after
          , 2000
        else
          mmm_gg_t = []
          while my_gildings_given_json.length > 0
            mmm_gg_t = mmm_gg_t.concat(my_gildings_given_json.shift())
          mmm_gg_t = JSON.stringify(mmm_gg_t.map((mmm_gg_n)->
            kind: mmm_gg_n.kind
            subreddit: mmm_gg_n.data.subreddit
            author: mmm_gg_n.data.author
          ))
          $('body > .container:first').html('<h1>Almost done...</h1><p>Just drawing some graphs...</p><form method="post" action="https://www.megamegamonitor.com/gilding-graph/"><input type="hidden" name="version" value="#{VERSION}" /><input type="hidden" name="u" /><input type="hidden" name="g" /></form>')
          $('input[name="u"]').val(mmm_gg_n)
          $('input[name="g"]').val(mmm_gg_t)
          $('form').submit()
    $('body > .container:first').html('<h1>Please wait<span id="mmm_gg_d"></span></h1><p>This will take a little over 2 seconds per 100 gildings you\'ve given. If it freezes for a long time (no dots appearing), Reddit probably went down again. :-(</p>')
    $.get '/api/me.json', (mmm_gg_n)->
      mmm_gg_l mmm_gg_n.data.name, ''
    false

  # Encryption functionality
  sub_encryption_select_box = $('#mmm-tools-encrypt-sub')
  userData.mySubreddits.forEach (cryptosub)->
    latest_crypto_key = cryptosub.cryptos[cryptosub.cryptos.length - 1]
    sub_encryption_select_box.append("<option value=\"#{latest_crypto_key[1]}\" data-crypto-id=\"#{latest_crypto_key[0]}\" data-sub-id=\"#{cryptosub.id}\">#{cryptosub.display_name}</option>")
  $('#mmm-tools-encrypt-submit').on 'click', ->
    encrypt_plaintext = $('#mmm-tools-encrypt-secret').val()
    encrypt_key = $('#mmm-tools-encrypt-sub').val()
    encrypt_crypto_id = $('#mmm-tools-encrypt-sub option:selected').data('crypto-id')
    encrypt_ciphertext = CryptoJS.AES.encrypt(encrypt_plaintext, encrypt_key).toString()
    $('#mmm-tools-encrypt-output').val("[#{$('#mmm-tools-encrypt-public').val()}](/r/MegaMegaMonitor/wiki/encrypted \"#{encrypt_crypto_id}:#{encrypt_ciphertext}\")")

  # Listing functionality
  $('.mmm-tools-list-submit').on 'click', ->
    $(this).prop('disabled', true).text 'Please wait |'
    wrapper = $(this).closest('.mmm-list')
    list_find = wrapper.find('.mmm-tools-list-find').val()
    list_sub = wrapper.find('.mmm-tools-list-sub').val()
    window.mmm_list_limit = wrapper.find('.mmm-tools-list-limit').val()
    window.mmm_list_limit = 999999999999999999999999 if window.mmm_list_limit == ''
    window.mmm_list_output_area = wrapper.find('.mmm-tools-list-output')
    window.mmm_list_output_area.text ''
    window.mmm_list_submit_button = wrapper.find('.mmm-tools-list-submit')
    window.mmm_list_finds = 0
    window.mmm_list_pages = 0
    window.mmm_list_after = ''
    window.mmm_list_results = []

    if list_find == 'everybody'
      window.mmm_list_url = "/r/#{list_sub}/about/contributors.json"
      mmmListProcessor = ->
        $.getJSON "#{window.mmm_list_url}?limit=100&after=#{window.mmm_list_after}", (json)->
          window.mmm_list_pages++
          window.mmm_list_after = json.data.after
          json.data.children.forEach (child)->
            if child.name != '[deleted]'
              window.mmm_list_finds++
              window.mmm_list_results.push(child.name)
          if (json.data.after != null) && (window.mmm_list_finds < window.mmm_list_limit)
            window.mmm_list_submit_button.text "Please wait #{['|', '/', '-', '\\'][window.mmm_list_pages % 4]} (#{window.mmm_list_pages}|#{window.mmm_list_finds})"
            setTimeout mmmListProcessor, 2000
          else
            window.mmm_list_submit_button.text 'Done!'
            setTimeout ->
              window.mmm_list_submit_button.prop('disabled', false).text 'Start'
            , 5000
          window.mmm_list_output_area.val window.mmm_list_results.join("\n")
      mmmListProcessor()

    if list_find == '3gildees'
      window.mmm_list_url = "/r/#{list_sub}/gilded.json"
      mmmListProcessor = ->
        console.log "#{window.mmm_list_url}?limit=100&after=#{window.mmm_list_after}"
        $.getJSON "#{window.mmm_list_url}?limit=100&after=#{window.mmm_list_after}", (json)->
          window.mmm_list_pages++
          window.mmm_list_after = json.data.after
          json.data.children.forEach (child)->
            mmm_search_new_gildee_name = child.data.author
            if (mmm_search_new_gildee_name != '[deleted]')
              found_existing_mmm_gildee = false
              window.mmm_list_results.forEach (existing_mmm_gildee)->
                if existing_mmm_gildee[0] == mmm_search_new_gildee_name
                  found_existing_mmm_gildee = true
                  console.log "Incrementing #{mmm_search_new_gildee_name} by #{child.data.gilded}"
                  existing_mmm_gildee[1] += child.data.gilded
              if !found_existing_mmm_gildee
                console.log "Found #{mmm_search_new_gildee_name} (#{child.data.gilded})"
                window.mmm_list_results.push([mmm_search_new_gildee_name, child.data.gilded])
          window.mmm_list_finds = 0
          mmm_list_output_area_triple_gilds = []
          window.mmm_list_results.forEach (mmm_found_gildee_and_count)->
            if (mmm_found_gildee_and_count[1] >= 3)
              console.log "#{mmm_found_gildee_and_count[0]} is a triple-gildee"
              window.mmm_list_finds++
              mmm_list_output_area_triple_gilds.push mmm_found_gildee_and_count[0]
          window.mmm_list_output_area.val mmm_list_output_area_triple_gilds.join("\n")
          if (json.data.after != null) && (window.mmm_list_finds < window.mmm_list_limit)
            window.mmm_list_submit_button.text "Please wait #{['|', '/', '-', '\\'][window.mmm_list_pages % 4]} (#{window.mmm_list_pages}|#{window.mmm_list_finds})"
            setTimeout mmmListProcessor, 2000
          else
            window.mmm_list_submit_button.text 'Done!'
            setTimeout ->
              window.mmm_list_submit_button.prop('disabled', false).text 'Start'
            , 5000
      mmmListProcessor()

    if list_find == 'gildees'
      window.mmm_list_url = "/r/#{list_sub}/gilded.json"
      mmmListProcessor = ->
        $.getJSON "#{window.mmm_list_url}?limit=100&after=#{window.mmm_list_after}", (json)->
          window.mmm_list_pages++
          window.mmm_list_after = json.data.after
          json.data.children.forEach (child)->
            mmm_search_new_gildee_name = child.data.author
            if (mmm_search_new_gildee_name != '[deleted]') && (window.mmm_list_results.indexOf(mmm_search_new_gildee_name) == -1)
              window.mmm_list_finds++
              window.mmm_list_results.push(mmm_search_new_gildee_name)
          if (json.data.after != null) && (window.mmm_list_finds < window.mmm_list_limit)
            window.mmm_list_submit_button.text "Please wait #{['|', '/', '-', '\\'][window.mmm_list_pages % 4]} (#{window.mmm_list_pages}|#{window.mmm_list_finds})"
            setTimeout mmmListProcessor, 2000
          else
            window.mmm_list_submit_button.text 'Done!'
            setTimeout ->
              window.mmm_list_submit_button.prop('disabled', false).text 'Start'
            , 5000
          window.mmm_list_output_area.val window.mmm_list_results.join("\n")
      mmmListProcessor()

  $('.mmm-tools-list-clear').on 'click', ->
    $(this).closest('.mmm-list').find('.mmm-tools-list-output').val ''
  $('#mmm-tools-list-copy-1-2').on 'click', ->
    $('#mmm-tools-list-2-output').val $('#mmm-tools-list-1-output').val()
  $('#mmm-tools-list-copy-2-1').on 'click', ->
    $('#mmm-tools-list-1-output').val $('#mmm-tools-list-2-output').val()
  $('#mmm-tools-list-copy-3-2').on 'click', ->
    $('#mmm-tools-list-2-output').val $('#mmm-tools-list-3-output').val()
  $('#mmm-tools-list-copy-2-3').on 'click', ->
    $('#mmm-tools-list-3-output').val $('#mmm-tools-list-2-output').val()
  $('#mmm-tools-filter-1-minus-2').on 'click', ->
    list1 = $('#mmm-tools-list-1-output').val().split "\n"
    list2 = $('#mmm-tools-list-2-output').val().split "\n"
    $('#mmm-tools-list-3-output').val(list1.filter((n)->
      list2.indexOf(n) == -1
    ).join("\n"))
  $('#mmm-tools-filter-2-minus-1').on 'click', ->
    list1 = $('#mmm-tools-list-1-output').val().split "\n"
    list2 = $('#mmm-tools-list-2-output').val().split "\n"
    $('#mmm-tools-list-3-output').val(list2.filter((n)->
      list1.indexOf(n) == -1
    ).join("\n"))
  $('#mmm-tools-filter-intersection').on 'click', ->
    list1 = $('#mmm-tools-list-1-output').val().split "\n"
    list2 = $('#mmm-tools-list-2-output').val().split "\n"
    $('#mmm-tools-list-3-output').val(list1.filter((n)->
      list2.indexOf(n) != -1
    ).join("\n"))
  $('#mmm-tools-filter-1-plus-2').on 'click', ->
    list1 = $('#mmm-tools-list-1-output').val().split "\n"
    list2 = $('#mmm-tools-list-2-output').val().split "\n"
    $('#mmm-tools-list-3-output').val(list1.join("\n") + "\n" + list2.filter((n)->
      list1.indexOf(n) == -1
    ).join("\n"))
  $('#mmm-tools-invite').on 'click', ->
    window.mmm_invite_to = prompt('Invite List 3 to which subreddit?')
    if(window.mmm_invite_to && window.mmm_invite_to.length > 0)
      $('#mmm-tools-invite').data('old-text', $('#mmm-tools-invite').text()).text('Warming up...').prop('disabled', true)
      $('#mmm-tools-list-3-log').text("With /r/#{window.mmm_invite_to}:")
      $.get '/api/me.json', (mejson)->
        window.modhash = mejson.data.modhash
        $('#mmm-tools-invite').text 'Waiting...'
        setTimeout mmmInvite, 2000
  false

mmmInvite = ->
  list3_invitees = $('#mmm-tools-list-3-output').val().split("\n")
  list3_invite_now = $.trim(list3_invitees.shift())
  if(list3_invite_now != '')
    $('#mmm-tools-invite').text "Inviting #{list3_invite_now}..."
    $.post "/r/#{window.mmm_invite_to}/api/friend", { api_type: 'json', type: 'contributor', name: list3_invite_now, uh: window.modhash }, (data)->
      if(data.json.errors && data.json.errors.length > 0)
        # failed invitation
        if(data.json.errors[0][0] == 'USER_DOESNT_EXIST')
          # user doesn't exist: non-critical
          $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"))
          $('#mmm-tools-list-3-log').append("\nFailed to invite #{list3_invite_now}: user doesn't exist!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
          if list3_invitees.length > 0
            $('#mmm-tools-invite').text 'Waiting...'
            setTimeout mmmInvite, 2000
          else
            $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
            $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false)
        if(data.json.errors[0][0] == 'BANNED_FROM_SUBREDDIT')
          # banned from sub: non-critical
          $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"))
          $('#mmm-tools-list-3-log').append("\nFailed to invite #{list3_invite_now}: user banned from sub!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
          if list3_invitees.length > 0
            $('#mmm-tools-invite').text 'Waiting...'
            setTimeout mmmInvite, 2000
          else
            $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
            $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false)
        else
          # critical error
          $('#mmm-tools-list-3-log').append("\nFailed to invite #{list3_invite_now}: #{data.json.errors[0][0]}\nSTOPPING HERE!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
          $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false)
      else
        # successful invitation
        $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"))
        $('#mmm-tools-list-3-log').append("\nInvited #{list3_invite_now}").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
        if list3_invitees.length > 0
          $('#mmm-tools-invite').text 'Waiting...'
          setTimeout mmmInvite, 2000
        else
          $('#mmm-tools-list-3-log').append("\nDone!").scrollTop($('#mmm-tools-list-3-log')[0].scrollHeight)
          $('#mmm-tools-invite').text($('#mmm-tools-invite').data('old-text')).prop('disabled', false)
  else
    # Invalid username: move on
    $('#mmm-tools-list-3-output').val(list3_invitees.join("\n"))
    mmmInvite()

mmmToolsFind = ->
  if window.mmm_tools_find_comment_cancel
    return false
  url = '/user/' + window.mmm_tools_find_comment_username + '/' + window.mmm_tools_find_comment_type + '.json?limit=100&after=' + window.mmm_tools_find_comment_after
  GM_xmlhttpRequest
    method: 'GET'
    url: url
    onload: (resp1) ->
      if window.mmm_tools_find_comment_cancel
        return false
      json = JSON.parse(resp1.responseText)
      window.mmm_tools_find_comment_after = json.data.after
      window.mmm_tools_find_comment_scanned += json.data.children.length
      json.data.children.forEach (child) ->
        if child.data.subreddit.toLowerCase() == window.mmm_tools_find_comment_subreddit
          # found one
          created_at_friendly = new Date(child.data.created_utc * 1000).toString()
          if child.data.name.search(/^t1_/) == 0
            # a comment
            $('#mmm-search-results').append "<li><a href=\"/#{child.data.link_id.substr(3)}##{child.data.id}\">Comment on #{child.data.link_title}</a> (#{created_at_friendly})</li>"
          else
            # a post
            $('#mmm-search-results').append "<li><a href=\"#{child.data.permalink}\">#{child.data.title}</a> (#{created_at_friendly})</li>"
        return
      $('#mmm-search-progress').text "#{window.mmm_tools_find_comment_scanned} possibilities scanned. #{$('#mmm-search-results li').length} results found."
      if json.data.after == null
        window.mmm_tools_find_comment_cancel = true
      else
        setTimeout mmmToolsFind, 2000
      return
  return

proveIdentity = (username, proof_required) ->
  log "MegaMegaMonitor Debug: proof of identity requested - #{proof_required}"
  url = "/r/#{proof_required}/about.json"
  log "GET #{url}"
  GM_xmlhttpRequest
    method: 'GET'
    url: url
    onload: (pr_resp) ->
      log "MegaMegaMonitor Debug: proof of identity requested - finding proof"
      proofData = JSON.parse(pr_resp.responseText)
      log proofData
      created_utc = "#{parseInt(proofData.data.created_utc)}"
      proof_response = md5(created_utc)
      log "MegaMegaMonitor Debug: proof response - #{proof_response}"
      url = 'https://www.megamegamonitor.com/identify.php'
      data = "version=#{VERSION}&username=#{username}&proof=#{proof_response}"
      log "POST #{url} #{data}"
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (pr_resp2) ->
          log "MegaMegaMonitor Debug: proof provided"
          proofData = JSON.parse(pr_resp2.responseText)
          log proofData
          if proofData.proof?
            log "MegaMegaMonitor Debug: proof failed"
            alert "MegaMegaMonitor wasn't able to verify your identity and will not run. If this problem persists, contact /u/avapoet for help."
          else if proofData.accesskey?
            new_accesskey = proofData.accesskey
            log "MegaMegaMonitor Debug: proof succeeded - associating accesskey #{new_accesskey} with username #{username}"
            accesskeys[username] = new_accesskey
            GM_setValue 'accesskeys', JSON.stringify(accesskeys)
            updateUserData()

updateUserData = ->
  log 'MegaMegaMonitor Debug: updateUserData()'
  GM_xmlhttpRequest
    method: 'GET'
    url: '/api/me.json'
    onload: (resp1) ->
      username = JSON.parse(resp1.responseText).data.name
      url = 'https://www.megamegamonitor.com/identify.php'
      data = "version=#{VERSION}&username=#{username}&accesskey=#{accesskeys[username]}"
      log "POST #{url} #{data}"
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (resp2) ->
          log 'MegaMegaMonitor Debug: updateUserData() - response received'
          userData = JSON.parse(resp2.responseText)
          log userData
          if userData.error?
            log 'MegaMegaMonitor Debug: updateUserData() - response received - error'
            alert userData.error
          else if userData.proof?
            log 'MegaMegaMonitor Debug: updateUserData() - response received - proof'
            proveIdentity username, userData.proof
          else
            log 'MegaMegaMonitor Debug: updateUserData() - response received - data'
            GM_setValue 'userData', JSON.stringify(userData)
            lastUpdated = Date.now()
            GM_setValue 'lastUpdated', JSON.stringify(lastUpdated)
            log 'MegaMegaMonitor Debug: updateUserData() - saved new values'
            $('#mmm-id').remove()
            modifyPage()

modifyPage = ->
  # if looking for options and options not open, open options
  if (window.location.pathname == "/r/MegaMegaMonitor/wiki/options") && ($('#mmm-options').length == 0)
    mmmOptions()

  if $('#mmm-id').length == 0
    $('#header-bottom-right .user').before '<span id="mmm-id" style="margin-right: 8px;">MMM</span>'
    $('#mmm-id').hover ->
      clearTimeout window.mmmIdTipRemover
      betweenOne = if userData.createdAtEnd? then new Date(userData.createdAtEnd).toRelativeTime() else 'some time ago'
      betweenTwo = if userData.createdAtStart? then new Date(userData.createdAtStart).toRelativeTime() else 'some time ago'
      betweenThree = new Date(lastUpdated).toRelativeTime()
      out = """
        <div class="mmm-tip-id">
          <p><strong>MegaMegaMonitor</strong></p>
          <p>
            <strong>Version:</strong> #{VERSION}<br />
            <strong>Data max age:</strong> #{betweenTwo} (<a href="#" id="mmm-update-now">check for update?</a>)
          </p>
          <ul>
            <li><a href="/r/MegaMegaMonitor/wiki/options" id="mmm-options">Options/Tools</a></li>
            <li><a href="/r/MegaMegaMonitor">Help</a></li>
          </ul>
        </div>
      """
      $(this).append out
      w_t = $('.mmm-tip').outerWidth()
      w_e = $(this).width()
      m_l = w_e / 2 - (w_t / 2)
      $('.mmm-tip').css 'margin-left', m_l + 'px'
      $(this).removeAttr 'title'
      $('.mmm-tip').fadeIn 200
    , ->
      window.mmmIdTipRemover = setTimeout ->
        $('.mmm-tip-id').remove()
      , 200
    $('#mmm-id').on('click', '#mmm-update-now', ->
      $('#mmm-id').text 'MMM updating...'
      updateUserData()
      false
    ).on 'click', '#mmm-options', mmmOptions

  # log 'MegaMegaMonitor Debug: modifyPage()'

  body = $('body')
  sitetable = $('.sitetable, .wiki-page-content')

  # Gossip
  if body.hasClass('profile-page') && !body.hasClass('mmm-profile-page-modified')
    log "MegaMegaMonitor Debug: viewing a profile page"
    $('.trophy-area').closest('.spacer').before "<div class=\"spacer\"><div class=\"sidecontentbox mmm-gossip-area\"><a class=\"helplink\" href=\"/r/megamegamonitor/wiki/gossip\">what's this?</a><div class=\"title\"><h1>GOSSIP</h1></div><ul class=\"content\" id=\"mmm-gossip-area-content\"><li>hi there</li></ul></div></div>"
    body.addClass 'mmm-profile-page-modified'

  if sitetable.find('.author:not(.mmm-ran), a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').length == 0
    # skip whole process if we've not added any more links AND there are no cryptoblocks to break... for now!
    log 'MegaMegaMonitor Debug: modifyPage() skipping (nothing to do!)'
    setTimeout modifyPage, 2500
    # run periodically, in case we're scrolling with NeverEndingReddit or we unfold a conversation
    return false
  thisLounge = ($('#header-img').attr('alt') or '').toLowerCase()
  # tidy up from previous runs, if necessary
  # log 'MegaMegaMonitor Debug: modifyPage() - tidying up'
  $('.mmm-icon:not(.mmm-icon-crypto)').remove()
  $('.content a.author.mmm-ran').removeClass 'mmm-ran'
  #log "MegaMegaMonitor Debug: working with suppressionList = #{JSON.stringify(suppressionList)}"

  # Add icons to users: old way
  #for user of userData.users
  #  sitetable_author = sitetable.find(".author[href$='/user/#{user}']:not(.mmm-ran)")
  #  if sitetable_author.length > 0
  #    log "MegaMegaMonitor Performance Debug [#{new Date()}]: #{user} (#{sitetable_author.length})"
  #    for i of userData.users[user]
  #      cssClass = userData.users[user][i][0]
  #      tip = userData.users[user][i][1]
  #      sub = userData.users[user][i][2]
  #      suppressionId = userData.users[user][i][3]
  #      #log "MegaMegaMonitor Debug: modifyPage() - #{cssClass} #{tip} #{sub} #{suppressionId}"
  #      if suppressionList.indexOf(suppressionId) == -1
  #        extraClasses = ''
  #        extraClasses += ' mmm-icon-current' if(tip.toLowerCase() == thisLounge)
  #        extraClasses += ' mmm-icon-tiny' if iconsize == 'tiny'
  #        #log 'MegaMegaMonitor Debug: modifyPage() - ' + user + ' ' + cssClass
  #        log "MegaMegaMonitor Performance Debug [#{new Date()}]: #{user} #{i} #{sub}"
  #        sitetable_author.after "<span data-sub=\"#{sub}\" data-tip=\"#{tip}\" class=\"mmm-icon #{cssClass}#{extraClasses}\"></span>"
  #      #else if debugMode
  #      #  console.log "MegaMegaMonitor Debug: suppressed #{suppressionId}"

  # Add icons to users: new way
  sitetable.find('.author:not(.mmm-ran)').each ->
    user = $(this).attr('href').split('/').pop()
    if user_userData = userData.users[user]
      # We have data on this user
      if user_userData.iconHtml?
        # We've precalculated HTML for this user
        $(this).after user_userData.iconHtml
      else
        # Generate HTML for this user
        iconHtmlTmp = ''
        for i of user_userData
          cssClass = user_userData[i][0]
          tip = user_userData[i][1]
          sub = user_userData[i][2]
          suppressionId = user_userData[i][3]
          if suppressionList.indexOf(suppressionId) == -1
            extraClasses = ''
            extraClasses += ' mmm-icon-current' if(tip.toLowerCase() == thisLounge)
            extraClasses += ' mmm-icon-tiny' if iconsize == 'tiny'
            iconHtmlTmp += "<span data-sub=\"#{sub}\" data-tip=\"#{tip}\" class=\"mmm-icon #{cssClass}#{extraClasses}\"></span>"
        user_userData.iconHtml = iconHtmlTmp
        $(this).after user_userData.iconHtml

  # Add tooltips to icons/flair
  $('.mmm-icon').hover((->
    desc = $(this).data('tip')
    if desc.match(/-plus$/)
      desc = 'Higher than ' + desc.substr(0, desc.length - 5)
    if $(this).hasClass('mmm-icon-current')
      desc += ' (current)'
    out = '<div class="mmm-tip">' + desc + '</div>'
    $(this).append out
    w_t = $('.mmm-tip').outerWidth()
    w_e = $(this).width()
    m_l = w_e / 2 - (w_t / 2)
    $('.mmm-tip').css 'margin-left', m_l + 'px'
    $(this).removeAttr 'title'
    $('.mmm-tip').fadeIn 200
  ), ->
    $('.mmm-tip').remove()
  ).dblclick ->
    tip_sub = $(this).data('sub')
    if tip_sub != ''
      window.location.href = '/r/' + tip_sub

  # Attempt decryption of MMM-encrypted content
  log 'MegaMegaMonitor Debug: considering decrypting things...'
  $('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').each ->
    log 'MegaMegaMonitor Debug: decrypting something!'
    ciphertext = $(this).attr('title').split(':')
    key = ''
    key_sub = ''
    spriteset_position_sub = 0
    key_id = parseInt(ciphertext[0])
    log "Attempting to decrypting ciphertext \"#{ciphertext[1]}\""
    for mmm_c_mySub in userData.mySubreddits
      for mmm_c_crypto in mmm_c_mySub.cryptos
        if mmm_c_crypto[0] == key_id
          key = mmm_c_crypto[1]
          key_sub = mmm_c_mySub.display_name
          spriteset_position_sub = mmm_c_mySub.spriteset_position
    if key != ''
      log "Attempting to decrypt using key \"#{key}\""
      if $(this).next().hasClass('keyNavAnnotation')
        $(this).next().remove()
      # tidy up in case RES has annotated the link already
      container = $(this).closest('p')
      try
        plaintext = CryptoJS.AES.decrypt(ciphertext[1], key).toString(CryptoJS.enc.Utf8)
        converter = new (Showdown.converter)
        html = converter.makeHtml(plaintext)
        plaintext_icon = "<span data-sub=\"#{key_sub}\" data-tip=\"Encrypted for #{key_sub} members only.\" class=\"mmm-icon mmm-icon-crypto mmm-icon-#{spriteset_position_sub}\"></span>"
        if container.text() == $(this).text()
          # entire paragraph exists only for crypto: replace entirely
          container.replaceWith "<div class=\"mmm-crypto-plaintext\" data-sub=\"#{key_sub}\">#{plaintext_icon} #{html}</div>"
        else
          # "inline" crypto: remove <p> tags from markdown html output and insert inline
          $(this).replaceWith "<span class=\"mmm-crypto-plaintext\" data-sub=\"#{key_sub}\">#{plaintext_icon} #{html.substring(3, html.length - 4)}</span>"
      catch err
        log 'Decryption error while decrypting ciphertext "' + ciphertext[1] + '" using key #' + key_id + ': ' + err
    else
      # no key for this ciphertext - remove title to prevent hitting this code again
      known_keys = userData.mySubreddits.map (sub_with_key)->
        sub_with_key.id
      log "Don't have an appropriate key (searched for #{key_id}, only found #{known_keys.join(', ')})"
      $(this).removeAttr 'title'

  sitetable.find('.author').addClass 'mmm-ran'

  # run periodically, in case we're scrolling with NeverEndingReddit or we unfold a conversation
  setTimeout modifyPage, 2500

if "#{lastVersion}" == VERSION
  # version is current: load data from local store, if available
  log "MegaMegaMonitor Debug: version (#{lastVersion}) is current"
  userData = JSON.parse(GM_getValue('userData', 'null'))
  lastUpdated = JSON.parse(GM_getValue('lastUpdated', 0))
  log userData
  log "(last updated #{lastUpdated})"
else
  log "MegaMegaMonitor Debug: version (#{lastVersion}) is not current (#{VERSION})"

dataAge = Date.now() - lastUpdated
suppressionList = JSON.parse(GM_getValue('suppressionList', '[]'))
log "MegaMegaMonitor Debug: loaded suppressionList = #{JSON.stringify(suppressionList)}"

# add CSS
$('head').append '<style type="text/css" id="mmm-css-block">{{css}}</style>'
$('body').addClass('mmm-installed')
if $('body').hasClass('loggedin')
  # run it!
  if dataAge > 21600000 # 86400000
    # 21600000 = milliseconds in 6 hours; 86400000 = milliseconds in a day
    log "MegaMegaMonitor Debug: At #{dataAge} seconds old, data is out of date. Updating."
    updateUserData()
  else
    log "MegaMegaMonitor Debug: At #{dataAge} seconds old, data is fresh. Cool."
    modifyPage()

###
