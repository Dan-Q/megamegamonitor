# debug mode?
debugMode = {{debug_mode}}

# set up jQuery
@$ = @jQuery = jQuery.noConflict(true)

# Dependencies
include 'src/date.extensions.js'
include 'src/showdown.js'
include 'src/aes.js'
include 'src/md5.js'

# load data from data store, if available
lastVersion = JSON.parse(GM_getValue('version', '{{version}}'))
accesskeys = JSON.parse(GM_getValue('accesskeys', '{}'))
iconsize = GM_getValue('iconsize', 'reg')
GM_setValue 'version', '{{version}}'
userData = null
lastUpdated = 0

# define methods
mmmGetNinjaPirateVisibility = ->
  GM_xmlhttpRequest
    method: 'GET'
    url: '/api/me.json'
    onload: (npvresp1) ->
      username = JSON.parse(npvresp1.responseText).data.name
      url = 'https://www.megamegamonitor.com/ninja_pirate_visible.php'
      data = "version={{version}}&username=#{username}&accesskey=#{accesskeys[username]}"
      console.log("POST #{url} #{data}") if debugMode
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (npvresp2) ->
          console.log(npvresp2.responseText) if debugMode
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
      data = "version={{version}}&username=#{username}&accesskey=#{accesskeys[username]}&v=#{visible ? 1 : 0}"
      console.log("POST #{url} #{data}") if debugMode
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (npvresp2) ->
          console.log 'MegaMegaMonitor Debug: mmmChangeNinjaPirateVisibility() - response received' if debugMode
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
    console.log("MegaMegaMonitor Debug: enumerating #{sub.display_name}") if debugMode
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
  #console.log("MegaMegaMonitor Debug: working with suppressionList = #{JSON.stringify(suppressionList)}") if debugMode
  suppressionList.forEach (id)->
    $("#mmm-options-hidden-subs-#{id}").prop('checked', true)
  # allow changing of "hidden" subs
  $('#mmm-options-hidden-subs input:checkbox').on 'click', ->
    suppressionList = $('#mmm-options-hidden-subs input:checkbox:checked').map ->
      $(this).data 'id'
    .toArray()
    console.log("MegaMegaMonitor Debug: writing suppressionList = #{JSON.stringify(suppressionList)}") if debugMode
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
          $('body > .container:first').html('<h1>Almost done...</h1><p>Just drawing some graphs...</p><form method="post" action="https://www.megamegamonitor.com/gilding-graph/"><input type="hidden" name="version" value="{{version}}" /><input type="hidden" name="u" /><input type="hidden" name="g" /></form>')
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
  console.log("MegaMegaMonitor Debug: proof of identity requested - #{proof_required}") if debugMode
  url = "/r/#{proof_required}/about.json"
  console.log("GET #{url}") if debugMode
  GM_xmlhttpRequest
    method: 'GET'
    url: url
    onload: (pr_resp) ->
      console.log("MegaMegaMonitor Debug: proof of identity requested - finding proof") if debugMode
      proofData = JSON.parse(pr_resp.responseText)
      console.log(proofData) if debugMode
      created_utc = "#{parseInt(proofData.data.created_utc)}"
      proof_response = md5(created_utc)
      console.log("MegaMegaMonitor Debug: proof response - #{proof_response}") if debugMode
      url = 'https://www.megamegamonitor.com/identify.php'
      data = "version={{version}}&username=#{username}&proof=#{proof_response}"
      console.log("POST #{url} #{data}") if debugMode
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (pr_resp2) ->
          console.log("MegaMegaMonitor Debug: proof provided") if debugMode
          proofData = JSON.parse(pr_resp2.responseText)
          console.log(proofData) if debugMode
          if proofData.proof?
            console.log("MegaMegaMonitor Debug: proof failed") if debugMode
            alert "MegaMegaMonitor wasn't able to verify your identity and will not run. If this problem persists, contact /u/avapoet for help."
          else if proofData.accesskey?
            new_accesskey = proofData.accesskey
            console.log("MegaMegaMonitor Debug: proof succeeded - associating accesskey #{new_accesskey} with username #{username}") if debugMode
            accesskeys[username] = new_accesskey
            GM_setValue 'accesskeys', JSON.stringify(accesskeys)
            updateUserData()

updateUserData = ->
  console.log('MegaMegaMonitor Debug: updateUserData()') if debugMode
  GM_xmlhttpRequest
    method: 'GET'
    url: '/api/me.json'
    onload: (resp1) ->
      username = JSON.parse(resp1.responseText).data.name
      url = 'https://www.megamegamonitor.com/identify.php'
      data = "version={{version}}&username=#{username}&accesskey=#{accesskeys[username]}"
      console.log("POST #{url} #{data}") if debugMode
      GM_xmlhttpRequest
        method: 'POST'
        url: url
        data: data
        headers: 'Content-Type': 'application/x-www-form-urlencoded'
        onload: (resp2) ->
          console.log 'MegaMegaMonitor Debug: updateUserData() - response received' if debugMode
          userData = JSON.parse(resp2.responseText)
          console.log(userData) if debugMode
          if userData.error?
            console.log 'MegaMegaMonitor Debug: updateUserData() - response received - error' if debugMode
            alert userData.error
          else if userData.proof?
            console.log 'MegaMegaMonitor Debug: updateUserData() - response received - proof' if debugMode
            proveIdentity username, userData.proof
          else
            console.log 'MegaMegaMonitor Debug: updateUserData() - response received - data' if debugMode
            GM_setValue 'userData', JSON.stringify(userData)
            lastUpdated = Date.now()
            GM_setValue 'lastUpdated', JSON.stringify(lastUpdated)
            console.log 'MegaMegaMonitor Debug: updateUserData() - saved new values' if debugMode
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
            <strong>Version:</strong> {{version}}<br />
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

  # console.log('MegaMegaMonitor Debug: modifyPage()') if debugMode
  
  body = $('body')
  sitetable = $('.sitetable, .wiki-page-content')

  if debugMode # gossip is debugMode-only, for now
    if body.hasClass('profile-page') && !body.hasClass('mmm-profile-page-modified')
      console.log("MegaMegaMonitor Debug: viewing a profile page") if debugMode
      $('.trophy-area').closest('.spacer').before "<div class=\"spacer\"><div class=\"sidecontentbox mmm-gossip-area\"><a class=\"helplink\" href=\"/r/megamegamonitor/wiki/gossip\">what's this?</a><div class=\"title\"><h1>GOSSIP</h1></div><ul class=\"content\" id=\"mmm-gossip-area-content\"><li>hi there</li></ul></div></div>"
      body.addClass 'mmm-profile-page-modified'

  if sitetable.find('.author:not(.mmm-ran), a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').length == 0
    # skip whole process if we've not added any more links AND there are no cryptoblocks to break... for now!
    console.log('MegaMegaMonitor Debug: modifyPage() skipping (nothing to do!)') if debugMode
    setTimeout modifyPage, 2500
    # run periodically, in case we're scrolling with NeverEndingReddit or we unfold a conversation
    return false
  thisLounge = ($('#header-img').attr('alt') or '').toLowerCase()
  # tidy up from previous runs, if necessary
  # console.log('MegaMegaMonitor Debug: modifyPage() - tidying up') if debugMode
  $('.mmm-icon:not(.mmm-icon-crypto)').remove()
  $('.content a.author.mmm-ran').removeClass 'mmm-ran'
  #console.log("MegaMegaMonitor Debug: working with suppressionList = #{JSON.stringify(suppressionList)}") if debugMode

  # Add icons to users: old way
  #for user of userData.users
  #  sitetable_author = sitetable.find(".author[href$='/user/#{user}']:not(.mmm-ran)")
  #  if sitetable_author.length > 0
  #    console.log("MegaMegaMonitor Performance Debug [#{new Date()}]: #{user} (#{sitetable_author.length})") if debugMode
  #    for i of userData.users[user]
  #      cssClass = userData.users[user][i][0]
  #      tip = userData.users[user][i][1]
  #      sub = userData.users[user][i][2]
  #      suppressionId = userData.users[user][i][3]
  #      #console.log("MegaMegaMonitor Debug: modifyPage() - #{cssClass} #{tip} #{sub} #{suppressionId}") if debugMode
  #      if suppressionList.indexOf(suppressionId) == -1
  #        extraClasses = ''
  #        extraClasses += ' mmm-icon-current' if(tip.toLowerCase() == thisLounge)
  #        extraClasses += ' mmm-icon-tiny' if iconsize == 'tiny'
  #        #console.log('MegaMegaMonitor Debug: modifyPage() - ' + user + ' ' + cssClass) if debugMode
  #        console.log("MegaMegaMonitor Performance Debug [#{new Date()}]: #{user} #{i} #{sub}") if debugMode
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
  console.log('MegaMegaMonitor Debug: considering decrypting things...') if debugMode
  $('a[href="/r/MegaMegaMonitor/wiki/encrypted"][title]').each ->
    console.log('MegaMegaMonitor Debug: decrypting something!') if debugMode
    ciphertext = $(this).attr('title').split(':')
    key = ''
    key_sub = ''
    spriteset_position_sub = 0
    key_id = parseInt(ciphertext[0])
    console.log("MegaMegaMonitor: Attempting to decrypting ciphertext \"#{ciphertext[1]}\"") if debugMode
    for mmm_c_mySub in userData.mySubreddits
      for mmm_c_crypto in mmm_c_mySub.cryptos
        if mmm_c_crypto[0] == key_id
          key = mmm_c_crypto[1]
          key_sub = mmm_c_mySub.display_name
          spriteset_position_sub = mmm_c_mySub.spriteset_position
    if key != ''
      console.log("MegaMegaMonitor: Attempting to decrypt using key \"#{key}\"") if debugMode
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
        console.log('MegaMegaMonitor: Decryption error while decrypting ciphertext "' + ciphertext[1] + '" using key #' + key_id + ': ' + err) if debugMode
    else
      # no key for this ciphertext - remove title to prevent hitting this code again
      if debugMode
        known_keys = userData.mySubreddits.map (sub_with_key)->
          sub_with_key.id
        console.log "MegaMegaMonitor: Don't have an appropriate key (searched for #{key_id}, only found #{known_keys.join(', ')})"
      $(this).removeAttr 'title'

  sitetable.find('.author').addClass 'mmm-ran'

  # run periodically, in case we're scrolling with NeverEndingReddit or we unfold a conversation
  setTimeout modifyPage, 2500
  
if "#{lastVersion}" == '{{version}}'
  # version is current: load data from local store, if available
  console.log "MegaMegaMonitor Debug: version (#{lastVersion}) is current" if debugMode
  userData = JSON.parse(GM_getValue('userData', 'null'))
  lastUpdated = JSON.parse(GM_getValue('lastUpdated', 0))
  console.log userData if debugMode
  console.log "(last updated #{lastUpdated})" if debugMode
else
  console.log "MegaMegaMonitor Debug: version (#{lastVersion}) is not current ({{version}})" if debugMode

dataAge = Date.now() - lastUpdated
suppressionList = JSON.parse(GM_getValue('suppressionList', '[]'))
console.log("MegaMegaMonitor Debug: loaded suppressionList = #{JSON.stringify(suppressionList)}") if debugMode

# add CSS
$('head').append '<style type="text/css" id="mmm-css-block">{{css}}</style>'
$('body').addClass('mmm-installed')
$('body').addClass('mmm-debugMode') if debugMode
if $('body').hasClass('loggedin')
  # run it!
  if dataAge > 21600000 # 86400000
    # 21600000 = milliseconds in 6 hours; 86400000 = milliseconds in a day
    console.log("MegaMegaMonitor Debug: At #{dataAge} seconds old, data is out of date. Updating.") if debugMode
    updateUserData()
  else
    console.log("MegaMegaMonitor Debug: At #{dataAge} seconds old, data is fresh. Cool.") if debugMode
    modifyPage()
