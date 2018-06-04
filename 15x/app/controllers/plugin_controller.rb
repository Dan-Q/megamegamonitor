require 'cssminify'

class PluginController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: [:install, :latest_version]
  before_filter :get_current_version
  after_filter :allow_cors_from_reddit, only: [:latest_version]

  UGLIFIER_OPTIONS = {
    production: {
      output: {
        comments: :none
      },
      compress: {
        drop_console: true
      }
    },

    alpha: {
      output: {
        comments: :all,                    beautify: true
      },
      mangle: false,
      compress: {
        sequences: false,                  properties: false,              dead_code: false,               drop_debugger: false,
        conditionals: false,               comparisons: false,             evaluate: false,                booleans: false,
        loops: false,                      unused: false,                  hoist_funs: false,              if_return: false,
        join_vars: false,                  cascade: false,                 negate_iife: false
      }
    }
  }

  def about
  end

  def install
    dir = "#{Rails.root}/app/views/plugin/versions/#{@current_version}"
    render(status: 404) and return unless File::exists?(coffee_filename = "#{dir}/mmm.coffee")
    html_compressor = HtmlCompressor::Compressor.new()
    @dependencies = Dir::glob("#{Rails.root}/lib/plugin-dependencies/*.js").map{|d| "/* MMM DEPENDENCY: #{d.gsub(/^.*\//,'')} */\n" + File::read(d) }
    @additional_coffee_strings = {}
    if File::exists?("#{dir}/list.coffee")
      @additional_coffee_strings['MMM_LISTS_COFFEE'] = File::read("#{dir}/list.coffee")
    end
    @javascript = (@dependencies + [Tilt::CoffeeScriptTemplate.new(coffee_filename, bare: true).render]).join("\n")
    @css = CSSminify.compress(Tilt::SassTemplate.new("#{dir}/style.sass").render)
    @options_html = html_compressor.compress(Tilt::HamlTemplate.new("#{dir}/options.html.haml").render).html_safe
    @start_html = html_compressor.compress(Tilt::HamlTemplate.new("#{dir}/start.html.haml").render).html_safe
    @uglifier_options = UGLIFIER_OPTIONS[(params[:version] ? :alpha : :production)]
    @debug_mode = !!params[:version]
  end

  def latest_version
    response.headers['Access-Control-Allow-Origin'] = 'HEADER VALUE'
    render json: @current_version, callback: params['callback']
  end

  protected

  def get_current_version
    @current_version = params[:version] || Dir::glob("#{Rails.root}/app/views/plugin/versions/*").select{|f|f=~/\/\d+$/}.map{|f|f=~/\/(\d+)$/;$1.to_i}.sort.last
  end
end
