##########################################################################
### List functions                                                     ###
##########################################################################

List =
  _mode: 'fast'
  _modhash: ''
  _subs: []

  set_subs:(subs) ->
    List._subs = subs

  # Executes front-end code, passing it up to the front-end if it detects
  # that we're probably running in a Worker thread
  exec: (code) ->
    if !window? || (window.document == undefined)
      # Probably running in a Worker
      postMessage code
    else
      # Almost certainly running directly
      eval code

  # Waits 2 seconds to throttle requests to the Reddit API
  tarpit: (ms = 2000)->
    now = new Date().getTime()
    finish = now + ms
    while(finish > now)
      now = new Date().getTime()

  mode: (val)->
    if (val == 'fast') || (val == 'slow') # setting
      List._mode = val
      List.exec "$('#mmm-list-mode').text('#{val}')"
    else                                  # getting
      List._mode

  # Returns a modhash, acquiring it if necessary
  modhash: ->
    return new Promise (resolve, reject)->
      if (List._modhash != '')
        resolve List._modhash
      else
        fetch 'https://www.reddit.com/api/me.json', { credentials: 'include' }
        .then (response)->
          if !response.ok then throw Error(response.statusText)
          response.json().then (json)->
            if !json.data.modhash? then throw Error('No modhash found in response.')
            List._modhash = json.data.modhash
            resolve List._modhash

  recursive_fetch: (url, progress_callback, limit, after = '', depth = 0)->
    List.tarpit()
    return new Promise (resolve, reject)->
      if limit? && depth > limit
        resolve []
      else
        fetch "#{url}?limit=100&after=#{after}", { credentials: 'include' }
        .then (response)->
          response.json().then (json)->
            after = json.data.after
            results = json.data.children
            if progress_callback? then progress_callback(depth)
            if after? && after != ''
              List.recursive_fetch(url, progress_callback, limit, after, depth + 1).then (inner_results)->
                results = results.concat(inner_results)
                resolve results
            else
              resolve results

  toggle_mode: ->
    List.mode(if (List.mode() == 'fast') then 'slow' else 'fast')

  output:
    clear: ->
      List.exec """
        $('#mmm-list-output').val('');
      """
    log: (text)->
      List.exec """
        var text = $('#mmm-list-output').val();
        text = text + unescape('#{escape(text)}');
        text = text + "\\n";
        $('#mmm-list-output').val(text);
      """

  known_subs: ->
    (sub.display_name for sub in List._subs when sub.id > 0)

  mmm_users: ->
    List.subreddit((sub.display_name for sub in List._subs when sub.id > 0)[0]).contributors()

  chain_subreddits: ->
    (List.subreddit(sub.display_name) for sub in List._subs when sub.chain_number)

  subreddit: (subreddit_display_name)->
    display_name: subreddit_display_name

    # /r/subreddit/api/friend
    friend: (name, type)->
      List.tarpit()
      #log 2, "Adding /u/#{name} to /r/#{subreddit_display_name} as contributor."
      List.modhash().then (modhash)->
        fetch "https://www.reddit.com/r/#{subreddit_display_name}/api/friend?name=#{name}&type=#{type}",
          method: 'POST'
          credentials: 'include'
          headers: { 'X-Modhash': modhash }
        .then (response)->
          if !response.ok then throw Error(response.statusText)

    add_contributor: (name)->
      List.subreddit(subreddit_display_name).friend name, 'contributor'

    ban: (name)->
      List.subreddit(subreddit_display_name).friend name, 'banned'

    mute: (name)->
      List.subreddit(subreddit_display_name).friend name, 'muted'

    # /r/subreddit/api/unfriend
    unfriend: (name, type)->
      List.tarpit()
      #log 2, "Adding /u/#{name} to /r/#{subreddit_display_name} as contributor."
      List.modhash().then (modhash)->
        fetch "https://www.reddit.com/r/#{subreddit_display_name}/api/unfriend?name=#{name}&type=#{type}",
          method: 'POST'
          credentials: 'include'
          headers: { 'X-Modhash': modhash }
        .then (response)->
          if !response.ok then throw Error(response.statusText)

    remove_contributor: (name)->
      List.subreddit(subreddit_display_name).unfriend name, 'contributor'

    unban: (name)->
      List.subreddit(subreddit_display_name).unfriend name, 'banned'

    unmute: (name)->
      List.subreddit(subreddit_display_name).unfriend name, 'muted'

    # /r/subreddit/about/contributors
    contributors: (progress_callback, limit)->
      return new Promise (resolve, reject)->
        fast_mode_sub = (sub for sub in List._subs when sub.display_name.toLowerCase() is subreddit_display_name.toLowerCase())[0]
        if (List.mode() == 'fast') && fast_mode_sub
          resolve (user[0] for user in fast_mode_sub.users)
        else
          List.recursive_fetch("https://www.reddit.com/r/#{subreddit_display_name}/about/contributors.json", progress_callback, limit).then (raw_results)->
            results = []
            raw_results.forEach (child)->
              if child.name != '[deleted]' then results.push(child.name)
            resolve results

    # /r/subreddit/gilded
    gilded: (progress_callback, limit)->
      return new Promise (resolve, reject)->
        List.recursive_fetch("https://www.reddit.com/r/#{subreddit_display_name}/gilded.json", progress_callback, limit).then (results)->
          resolve results
