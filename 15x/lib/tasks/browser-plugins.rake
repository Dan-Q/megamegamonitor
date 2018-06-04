desc 'Compiles browser plugin versions of MMM'
task :'browser-plugins' => :environment do
  URL = 'https://dev.megamegamonitor.com/'
  VERSION = Dir::glob("#{Rails.root}/app/views/plugin/versions/*").select{|f|f=~/\/\d+$/}.map{|f|f=~/\/(\d+)$/;$1.to_i}.sort.last
  
  # Chrome
  `rm -rf #{Rails.root}/tmp/browser-plugins/chrome` if File::exists?("#{Rails.root}/tmp/browser-plugins/chrome")
  `mkdir -p #{Rails.root}/tmp/browser-plugins/chrome`
  # Chrome: Manifest
  File::open("#{Rails.root}/tmp/browser-plugins/chrome/manifest.json", 'w') do |f|
    f.puts({
      name: 'MegaMegaMonitor',
      description: 'Find Redditors you share private subs with, and much more.',
      homepage_url: URL,
      version: VERSION.to_s,
      manifest_version: 2,
      default_locale: 'en',
      icons: {
        '128': 'icon128.png'
      },
#      applications: {
#        gecko: {
#          id: 'mmm@megamegamonitor.com'
#        }
#      },
      content_scripts: [
        {
          matches: ['*://reddit.com/*', '*://*.reddit.com/*', '*://*.megamegamonitor.com/*', '*://*.megamegamonitor.com:*/*'],
          js: ['mmm.injector.js']
        }
      ],
#      web_accessible_resources: [
#        'mmm.user.js'
#      ]
    }.to_json)
  end
  # Chrome: Icons
  # Chrome: Files
  `cp "#{Rails.root}/public/images/icon128.png" "#{Rails.root}/tmp/browser-plugins/chrome/"`
  `wget #{URL}mmm.user.js -q -O "#{Rails.root}/tmp/browser-plugins/chrome/mmm.user.js"`
  requirements = `grep "^// @require" "#{Rails.root}/tmp/browser-plugins/chrome/mmm.user.js"`.split("\n").map{|r|r =~ /\/\/ +@require +(\S+)/; $1}
  # Chrome: Injector
  File::open("#{Rails.root}/tmp/browser-plugins/chrome/mmm.injector.js", 'w') do |f|
#    f.puts <<-EOF
#      var mmm_requirements = [#{requirements.map{|r|"'#{r}'"}.join(',')}];
#      for (var i = 0; i < mmm_requirements.length; i++){
#        var mmm_r_scr = top.window.content.document.createElement('script');
#        mmm_r_scr.type = 'text/javascript';
#        mmm_r_scr.setAttribute('src', mmm_requirements[i]);
#        top.window.content.document.getElementsByTagName('body')[0].appendChild(mmm_r_scr);
#      }
#      var mmm_scr = top.window.content.document.createElement('script');
#      mmm_scr.type = 'text/javascript';
#      mmm_scr.setAttribute('src', chrome.extension.getURL('mmm.user.js'));
#      top.window.content.document.getElementsByTagName('body')[0].appendChild(mmm_scr);
#    EOF
  end
  requirements.each do |req|
    `curl -s #{req} >> "#{Rails.root}/tmp/browser-plugins/chrome/mmm.injector.js"`
    `echo "" >> "#{Rails.root}/tmp/browser-plugins/chrome/mmm.injector.js"`
  end
  `cat "#{Rails.root}/tmp/browser-plugins/chrome/mmm.user.js" >> "#{Rails.root}/tmp/browser-plugins/chrome/mmm.injector.js"`
  `rm "#{Rails.root}/tmp/browser-plugins/chrome/mmm.user.js"`
  # Chrome: Package
  `chdir "#{Rails.root}/tmp/browser-plugins/chrome/" && zip MegaMegaMonitor.zip manifest.json mmm.injector.js icon128.png`



  # Firefox: Sign
  # puts `jpm sign --api-key user:12088533:825 --api-secret SIGNING SECRET KEY --xpi "#{Rails.root}/tmp/browser-plugins/firefox/MegaMegaMonitor.xpi"`
end
