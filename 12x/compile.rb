#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
#!/usr/bin/env ruby

DEV_VERSION             = "121.#{Time::now.to_i}".to_f
NEXT_VERSION            = DEV_VERSION.ceil

#UPLOAD_TO_S3            = false
#NEXT_USES_CURRENT_ICONS = true

require './megamegamonitor'
require 'open3'
require 'uglifier'
require 'cssminify'
require 'htmlcompressor'

# Escape Javascript tool adapted from Rails ActionView
JS_ESCAPE_MAP   =   { '\\' => '\\\\', '</' => '<\/', "\r\n" => '\n', "\n" => '\n', "\r" => '\n', '"' => '\\"', "'" => "\\'" }
def j(javascript)
  (javascript || '').gsub(/(\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"'])/u) {|match| JS_ESCAPE_MAP[match] }
end

# Processes Ruby code inside {{...}} in the provided string
def moustache(input, version, css, download_url, debug_mode, snippets)
  input.gsub(/\{\{(.+?)\}\}/) { eval($1) }
end

def includer(input)
  input.gsub(/include\('(.+?)'\);/) { File::read($1) }
end

def compile(output, version, download_url, debug_mode, uglify = true)
  html_compressor = HtmlCompressor::Compressor.new
  snippets = {}
  Dir::new('src/').to_a.each do |f|
    if f =~ /^([a-z\-]*)\.html$/
      snippets[$1] = html_compressor.compress(File::read("src/#{f}"))
    end
  end
  puts "Compiling: #{output} (v#{version})"
  spriteset = Subreddit::where('spriteset_position IS NOT NULL').order(:spriteset_position).pluck(:spriteset_position).collect do |i|
    offset = i * 24
    tiny_offset = offset / 2
    <<-END_OF_CSS
      .mmm-icon.mmm-icon-#{i} { background-position: 0 -#{offset}px; }
      .mmm-icon.mmm-icon-#{i}.mmm-icon-current { background-position: -32px -#{offset}px; }
      .mmm-icon.mmm-icon-#{i}-plus { background-position: -64px -#{offset}px; }
      .mmm-icon.mmm-icon-tiny.mmm-icon-#{i} { background-position: 0 -#{tiny_offset}px; }
      .mmm-icon.mmm-icon-tiny.mmm-icon-#{i}.mmm-icon-current { background-position: -16px -#{tiny_offset}px; }
      .mmm-icon.mmm-icon-tiny.mmm-icon-#{i}-plus { background-position: -32px -#{tiny_offset}px; }
    END_OF_CSS
  end
  css = CSSminify.compress(moustache(File::read('src/mmm.css'), version, css, download_url, debug_mode, snippets) + spriteset.join(' '))
  File::open(output, 'w') do |f|
    js = File.read('src/mmm.js.coffee')
    js.gsub!(/^ *console\.log.* if debugMode *\n/,'') if !debug_mode
    js = moustache(js, version, css, download_url, debug_mode, snippets)
    Open3::popen2('coffee --compile --stdio --bare --no-header') do |i,o|
      i.print js
      i.close
      js = o.read
    end
    js = includer(js)
    js = Uglifier.new(output: { comments: :none }, screw_ie8: true).compile(js) if uglify
    f.puts moustache(File::read('src/header.js'), version, css, download_url, debug_mode, snippets)
    f.puts js
  end
end

# Compile JS
compile('bin/MegaMegaMonitor.next.user.js', DEV_VERSION, "https://www.megamegamonitor.com/bin/MegaMegaMonitor.next.user.js?#{Time::now.to_i}", 'true', false)
compile('bin/MegaMegaMonitor.next.compressed.user.js', NEXT_VERSION, "https://www.megamegamonitor.com/MegaMegaMonitor.user.js", 'false')
puts "\nTo deploy v#{NEXT_VERSION}:\n  cp bin/MegaMegaMonitor.next.compressed.user.js src/mmm.user.js"

#if UPLOAD_TO_S3
#  # Push spriteset to S3
#  puts "Uploading icons to S3..."
#  puts `s3cmd put icons.png s3://megamegamonitor/icons#{VERSION}.png`
#  puts `s3cmd put icons-next.png s3://megamegamonitor/icons#{NEXT_VERSION}.png`
#end
