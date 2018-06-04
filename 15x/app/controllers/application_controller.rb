class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  protected

  # after_filter this method to CORS-permit any request from an agent originating on a Reddit domain
  def allow_cors_from_reddit
    if request.headers['Origin'] =~ /^https?:\/\/([a-z0-9]+\.)*reddit\.com\/?$/
      response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
      response.headers['Access-Control-Request-Method'] = %w{HEAD GET POST OPTIONS}.join(',')
    end
  end

  # before_filter this method to disable access when in production
  def development_only
    render(text: 'Not found', status: 404) and return unless Rails.env.development?
  end
end
