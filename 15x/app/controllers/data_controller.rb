class DataController < ApplicationController
  before_filter :get_user_from_accesskey
  after_filter :allow_cors_from_reddit

  UNVERSAL_CRYPTOKEYS = [[-1, '238a0bfad290d721a4058a8ce74546aa3fbbf64a']] # cryptokeys shared by all MMM users: non-secret

  def get
    # Preload super-special people
    super_special_people_ids = Subreddit.find_by_display_name('MegaMegaMegaMonitor').contributors.pluck(:user_id)

    # Preload the entire MegaChain (we'll need the latter in order to put "+"s by people who are "higher" than you): we strip them out later
    # But NOT the "super special" people, even if we're also a MegaMegaMegaMonitor member
    subs = Subreddit.where('(subreddits.id IN (?) OR subreddits.chain_number IS NOT NULL) AND subreddits.icon_default_file_size IS NOT NULL AND subreddits.display_name <> ?', @user_sub_ids, 'MegaMegaMegaMonitor').
                     preload(:contributors, :cryptokeys).
                     with_monitored_contributors.
                     order("IF(subreddits.display_name = 'MegaMegaMegaMonitor', 1, 0) DESC, subreddits.chain_number DESC, subreddits.display_name ASC").
                     all

    seen_in_chain = [] # maintain a list of people already seen in the MegaChain
    css = '' # create a string of CSS for the subreddit icons I can see
    subs_output = subs.map do |sub|
      sub_users_output = sub.contributors.map{|c|[c.display_name, c.tooltip_suffix.to_s]}.sort
      if sub.chain_number?
        # in MegaChain - use slightly different processing so that we only see people in their HIGHEST lounge
        sub_users_output.each do |co|
          if seen_in_chain.include?(co[0])
            co[1] = '+' # put a single plus sign into the tooltip space; this will be interpreted at the front-end
          else
            # not yet seen in chain; this must be their highest level: append to seen in chain list for next level
            seen_in_chain << co[0]
          end
        end
      end
      if @user_sub_ids.include?(sub.id) # user is in this sub and so gets data (need to check this, because we always process the whole MegaLounge chain)
        # generate CSS relating to this sub
        css << ".mmm-icon.mmm-icon-#{sub.id}{background-image:url(#{sub.encoded_icon_default});}"                       # default icon
        css << ".mmm-in-sub-#{sub.id} .mmm-icon.mmm-icon-#{sub.id}{background-image:url(#{sub.encoded_icon_current});}" # "current sub" variant
        if sub.chain_number?
          css << ".mmm-icon.mmm-icon-plus.mmm-icon-#{sub.id}{background-image:url(#{sub.encoded_icon_higher});}"          # "higher sub than you" variant
        end
        # get this sub's representation in the JSON:
        {
          id: sub.id,
          display_name: sub.display_name,
          chain_number: sub.chain_number,
          cryptokeys: sub.cryptokeys.map{|k|[k.id, k.secret_key]}.sort.reverse,
          users: sub_users_output
        }
      else
        nil
      end
    end.reject(&:nil?) # remove nils (which occur for 'higher' chain MegaLounges)
    # Prepend data about MMM users, including the Super Special ones
    subs_output.unshift({
      id: -1,
      display_name: 'Uses MegaMegaMonitor',
      chain_number: nil,
      cryptokeys: UNVERSAL_CRYPTOKEYS,
      users: User::where('installation_seen_at >= ?', 1.week.ago).map{|user|
        [user.display_name, (super_special_people_ids.include?(user.id) ? '+' : '')]
      }
    })
    css << ".mmm-icon.mmm-icon--1{background-image:url(data:image/png;base64,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);}" # default icon
    css << ".mmm-icon.mmm-icon-plus.mmm-icon--1{background-image:url(data:image/png;base64,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);}" # super special icon
    # render the resulting JSON:
    render json: {
      oldest: subs.sort_by(&:updated_at).last.updated_at,
      youngest: subs.sort_by(&:updated_at).first.updated_at,
      subs: subs_output,
      css: css
    }
  end

  def changes
    @changes = Contributor.order('contributors.date DESC').where('contributors.date > ?', 2.weeks.ago).includes(:subreddit)
              .where('subreddits.id IN (?)', @user_sub_ids).references(:subreddits)
              .pluck('contributors.display_name, subreddits.id, subreddits.display_name, contributors.date')
    respond_to do |format|
      format.html # changes.html.erb
      format.json { render json: @changes }
    end
  end

  private

  def get_user_from_accesskey
    # Try to get user, report error on fail
    if !(@user = User.where(display_name: params[:username]).includes(:accesskeys).where('accesskeys.secret_key = ?', params[:accesskey]).references(:accesskeys).first)
      render(json: { error: { code: 'invalid_accesskey', message: 'Your MMM accesskey was not valid.' } }) and return
    end
    # Mark that this user is active
    @user.installation_seen_at = Time.now
    @user.save
    # We preload all of the user's subs,
    @user_sub_ids = @user.subreddits.pluck(:id)
  end
end
