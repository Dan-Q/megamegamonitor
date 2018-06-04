class SubredditController < ApplicationController
  before_filter :development_only
  before_filter :load_subreddit, only: [:show, :edit, :update, :destroy]

  def index
    @subreddits = Subreddit::all.eager_load(:account).order(:chain_number, :display_name, :account_id)
  end

  def new
  end

  def create
  end

  def show
  end

  def edit
    redirect_to @subreddit
  end

  def update
    @subreddit.update!(subreddit_params)
    render 'show'
  end

  def destroy
  end

  protected
  def load_subreddit
    render(text: 'Not found', status: 404) and return unless @subreddit = Subreddit::find_by_id(params[:id])
  end

  def subreddit_params
    params.require(:subreddit).permit(:icon_default, :icon_current, :icon_higher, :monitor_contributors, :monitor_gildings, :reencode_existing_icons, :new_cryptokey, :chain_number)
  end
end
