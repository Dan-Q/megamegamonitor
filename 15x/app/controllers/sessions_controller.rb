class SessionsController < ApplicationController
  def new
    redirect_to "/auth/reddit#{params[:handler]}"
  end

  def create
    identity = request.env['omniauth.auth']['extra']['raw_info']
    if @user = User.find_by_name("t2_#{identity['id']}")
      ak = @user.accesskeys.new
      raise ak.errors.full_messages.inspect unless ak.save
      @user.reload
    else
      # TODO: @user = User.create(name: ..., display_name: ...)
      render(text: "Didn't recognise you, #{identity['name']}...") and return
    end
    redirect_to "https://www.reddit.com/r/MegaMegaMonitor/wiki/options?setaccessuser=#{@user.display_name}&setaccesskey=#{@user.accesskeys.last.secret_key}"
  end
end
