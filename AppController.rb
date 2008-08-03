#
#  AppController.rb
#  iWassr
#
#  Created by Keiji Yoshimi on 08/07/05.
#  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
#

require 'osx/cocoa'
require 'uri'
require 'net/http'
require 'erb'
require 'open-uri'
require 'abbrev'

begin
  require 'json'
rescue LoadError => e
  $LOAD_PATH.unshift(File.expand_path(File.join( File.dirname(__FILE__), 'vendor', 'json-1.1.3', 'lib')))
  require 'json/pure'
end

begin
  require 'osx/hotkey'
rescue LoadError => e
  $LOAD_PATH.unshift(File.expand_path(File.join( File.dirname(__FILE__), 'vendor', 'osxhotkey', 'lib')))
  $LOAD_PATH.unshift(File.expand_path(File.join( File.dirname(__FILE__), 'vendor', 'osxhotkey', 'ext')))
  require 'osx/hotkey'
end

Net::HTTP.version_1_2

class AppController < OSX::NSObject
  include OSX
  include ERB::Util

  OSX.require_framework 'WebKit'
  WASSR_API_BASE = URI('http://api.wassr.jp/')
  MAX_STATUS = 2000
  MAX_FAV_HISTORY = 10

  ib_outlet :window, :main_view, :input_field, :pref_panel, :total_view, :nick_view, :channel_view

  def awakeFromNib

    NSUserDefaults.standardUserDefaults.synchronize

    NSApp.delegate = self
    @window.delegate = self
    # register hotkey
    NSApp.register_hotkey('COMMAND+SHIFT+;') do
      if NSApp.isActive?
        NSApp.hide(nil)
      else
        NSApp.activateIgnoringOtherApps(true)
        @window.orderFrontRegardless
        @window.makeKeyAndOrderFront(@window)
      end
    end

    @window.title = 'iWassr'
    @window.alphaValue = 0.9
    @main_view.customUserAgent = "iWassr/0.0.1 (#{ login_id })"
    @policy = MainViewPolicy.alloc.init
    @main_view.policyDelegate = @policy
    @main_view.uIDelegate = self
    
    @growl = GrowlController.new
    @growl.owner = self
    @growl.register

    init_loading
    NSTimer.objc_send(:scheduledTimerWithTimeInterval, 90, 
      :target, self, 
      :selector, 'update', 
      :userInfo, nil,
      :repeats, true
    )

    @fav_history = []
  end

  def windowDidBecomeMain notification
    @window.makeFirstResponder(@input_field)
  end

  def applicationDidHide notification
    NSApp.unhideWithoutActivation
  end

  def login_id
    NSUserDefaults.standardUserDefaults[:LoginID]
  end

  def password
    NSUserDefaults.standardUserDefaults[:Password]
  end

  # FIXME: umm, it seems that check is reversed.
  def follow_tail?
    !NSUserDefaults.standardUserDefaults[:FollowTail].to_ruby
  end

  def init_loading
    json = _get_json
    main_body = json.map {|status|
      warn status.inspect
      _generate_box(status)
    }.join(%Q{\n})

    @data = json.reverse
    @user_id_list = json.map {|status| status['user_login_id'] }.reject {|item| item.nil? }.sort.uniq
    html = init_html(main_body)

    @main_view.mainFrame.objc_send(:loadHTMLString, html, 
      :baseURL, NSURL.URLWithString('http://iwassr.walf443.org/')
    )
  end

  def update
    updated_items = []
    _get_json.each do |status|
      warn status.inspect
      unless @data.find {|item| item['rid'] == status['rid'] }
        updated_items.push(status)
        @data.unshift(status)
      end
    end
    updated_body = updated_items.map {|status|
      _generate_box(status)
    }.join(%Q{\n})

    ( @data.size - MAX_STATUS ).times do |i|
      if remove_first_item
        @data.pop
      end
    end

    doc = @main_view.mainFrame.DOMDocument
    if doc
      doc.body.innerHTML = doc.body.innerHTML + updated_body
    end

    updated_items.each do |item|
      image = NSImage.alloc.initWithContentsOfURL(NSURL.URLWithString(item['user']['profile_image_url']))
      @growl.notify(:status, "#{item['user']['screen_name']} (#{item['user_login_id']}) item updated", "#{item['text']}", :icon => image)
      if item['user_login_id']
        unless @user_id_list.include?(item['user_login_id'])
          @user_id_list.push item['user_login_id']
          @user_id_list.sort!
        end
      end
    end
    p @user_id_list

    if follow_tail?
      moveToBottom
    end
  end
  ib_action :update

  def _get_json
    json = []
    begin
      ( WASSR_API_BASE + "statuses/friends_timeline.json" ).open('User-Agent' => @main_view.customUserAgent, :http_basic_authentication => [ login_id, password ]) do |f|
        str = f.read
        json = JSON.parse(str)
      end
    rescue Exception => e
      warn e
      return []
    end
    
    return json.sort_by {|status| status['epoch'] }
  end

  def remove_first_item
    doc = @main_view.mainFrame.DOMDocument
    return unless doc
    if doc.body.firstChild
      doc.body.removeChild(doc.body.firstChild) 
    end
  end

  def init_html body
    str = <<-END_OF_HTML
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
      <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <meta http-equiv="Content-Script-Type" content="text/javascript">
        <meta http-equiv="Content-Style-Type" content="text/css">
        <title>iWassr</title>
        <style>
          #body {
             margin: 0;
             margin-left: 5px;
             padding: 0;
             color: #ffffff;
             background-color: #000000;
          }
          a {
            color: #5555ff;
          }
          .status {
             display: -webkit-box;
             width: 100%;
             margin-top: 1px;
             border-bottom: solid 2px #ffffff;
          }
          .user {
            display: -webkit-box;
            -webkit-box-sizing: 60px;
            width: 60px;
            vertical-align: -webkit-baseline-middle;
          }
          .user_icon {
            display: -webkit-inline-box;
            width: 40px;
            vertical-align: -webkit-baseline-middle;
          }
          .user_login_id {
             display: -webkit-inline-box;
             width: 40px;
             color: #00ff00;
             vertical-align: -webkit-baseline-middle;
          }
          .user_login_id a {
            color: inherit;
          }
          .message {
            display: -webkit-nowrap;
            width: 70%;
            vertical-align: -webkit-baseline-middle;
          }
          .created_at {
            display: -webkit-box;
            text-align: right;
            color: #9999ff;
            width: 10%;
          }
          .created_at a {
            color: inherit;
          }
          .clear-both {
            clear: both;
            height: 1px;
          }
        </style>
      </head>
        <body id="body">
          #{body}
        </body>
      </html>
    END_OF_HTML
  end

  REPLY_REGEX = /^@([a-zA-Z][a-zA-Z0-9]+)/

  def _generate_box status
    time = Time.at(status['epoch'])

    # It shoud process first.
    # FIXME: for avoiding emoticon, using status['text']. 
    msg = status['html']
    URI.extract(h(status['text']), %w(http https) ).uniq.each do |uri|
      msg = msg.gsub(uri, %{<a class="external_link" href="#{ uri }">#{ _truncate_uri(uri.to_s, 40) }</a>})
    end

    # Hack for none @ mark user reply.
    if ( status['reply_user_login_id'] ) 
      if ( msg =~ REPLY_REGEX) 
        msg = msg.gsub(/^@([a-zA-Z][a-zA-Z0-9]*)/) { %Q{@<a class="reply_user_login_id" href="http://wassr.jp/user/#{h status['reply_user_login_id'] }" title="#{h status['reply_user_login_id'] }: #{h status['reply_message'] }">#$1</a> } }
      else
        msg = %Q{@<a class="reply_user_link" href="http://wassr.jp/user/#{h status['reply_user_login_id'] }" title="#{h status['reply_user_login_id'] }: #{h status['reply_message'] }">#{h status['reply_user_login_id'] }</a> #{ msg } }
      end
    end

    if status['photo_url']
      msg = %{#{msg} <a href="#{ h status['photo_url'] }"><img class="photo_thumbnail" src="#{ h status['photo_thumbnail_url'] }" /></a>}
    end

    str = <<-EOF_STATUS
    <div class="item">
      <div class="status" id="#{h status['rid'] }">
        <div class="user" title="#{h status['user']['screen_name'] } ( #{h status['user_login_id'] } )">
          <div class="user_icon"><img src="#{h status['user']['profile_image_url'] }" width="22" height="22"></img></div>
          <div class="user_login_id"><a href="http://wassr.jp/user/#{h status['user_login_id'] }">#{h status['user_login_id'] }</a></div>
        </div>
        <div class="message">#{ msg }</div>
        <div class="created_at" title="#{ time.strftime('%Y-%m-%d %H:%M:%S') }"><a href="#{h status['link'] }">#{ time.strftime('%H:%M:%S') }</a></div>
      </div>
      <div class="clear-both">&nbsp;</div>
      <div class="status-separetor"></div>
    </div>
    EOF_STATUS
  end

  def _truncate_uri uri, length
    if uri.size > length
      uri[0..(length - 3)] + "..."
    else
      return uri
    end
  end

  def moveToBottom
    doc = @main_view.mainFrame.DOMDocument
    return unless doc
    body = doc.body
    return unless body
    body.setScrollTop(body.scrollHeight)
  end

  CMD_REGEX = /^:([A-Za-z0-9_]+)/

  ib_action :onPost do |sender|
    message = @input_field.stringValue.to_s
    if !message.nil? and message != ''
      @input_field.stringValue = ''
      if message =~ CMD_REGEX
        cmd = $1
        args = message.split(' ')
        args.shift
        if respond_to? "cmd_#{cmd}", true
          __send__ "cmd_#{cmd}", *args
        else
          warn 'no such command!!'
        end
      else
        begin
          api_post('/statuses/update.json', {
            'source' => 'iWassr',
            'status' => message,
          })
          update
        rescue RuntimeError => e
          warn "#{e}: #{message}"
        end
      end
    end
    moveToBottom unless follow_tail? # always move to bottom on post message.
  end

  def commands
    methods.grep(/^cmd_(.*)/).map {|meth| meth.sub(/^cmd_(.*)/, $1) }
  end

  def cmd_reload *args
    update
  end

  def cmd_favmsg *args
    msg = args.shift
    msg_regex = /#{msg}/
    target_status = @data.find  {|status|
      status['text'] =~ msg_regex
    }

    if target_status
      begin
        api_post "/favorites/create/#{ target_status['rid'] }.json" 
        @fav_history.push target_status
        if @fav_history.size > MAX_FAV_HISTORY
          @fav_history.shift
        end
        warn "fav: #{target_status['user_login_id']}: #{target_status['text']} (#{ target_status['rid'] })"
        @growl.notify(:fav, "fav: #{target_status['user_login_id']}", "#{target_status['text']} (#{ target_status['rid']})")
      rescue RuntimeError => e
        warn e
      end
    else
      warn "no match message: #{msg}"
    end
  end

  def cmd_favuser *args
    login_id = args.shift
    msg = ( args.size > 0 ) ? args.shift : nil

    target_status = nil
    if msg 
      msg_regex = /#{msg}/
      target_status = @data.find {|status|
        status['user_login_id'] == login_id && status['text'] =~ msg_regex
      }
    else
      target_status = @data.find {|status|
        status['user_login_id'] == login_id
      }
    end

    if target_status
      begin
        api_post "/favorites/create/#{ target_status['rid'] }.json" 
        @fav_history.push target_status
        if @fav_history.size > MAX_FAV_HISTORY
          @fav_history.shift
        end
        warn "fav: #{target_status['user_login_id']}: #{target_status['text']} (#{ target_status['rid'] })"
        @growl.notify(:fav, "fav: #{target_status['user_login_id']}", "#{target_status['text']} (#{ target_status['rid']})")
      rescue RuntimeError => e
        warn e
      end
    else
      warn "no such user: #{login_id}"
    end
  end

  def cmd_defav *args
    target = @fav_history.pop
    if target
      begin
        api_post("/favorites/destroy/#{ target['rid'] }.json")
        warn "defav: #{ target['user_login_id'] }: #{ target['text'] } (#{ target['rid'] })"
        @growl.notify(:defav, "defav: #{target['user_login_id']}", "#{target['text']} (#{ target['rid']})")
      rescue RuntimeError => e
        @fav_history.push(target)
        warn e
      end
    else
      warn 'no favorites history'
    end
  end

  alias cmd_fav cmd_favuser

  def api_post path, args={}
    res = nil
    Net::HTTP.start(WASSR_API_BASE.host) do |http|
      req = Net::HTTP::Post.new(path, { 
        'User-Agent' => @main_view.customUserAgent.to_s,
      })
      req.basic_auth login_id, password
      req.set_form_data(args)
      res = http.request req
    end

    case res
    when Net::HTTPOK
      return true
    else
      raise RuntimeError, res.inspect
    end
  end

  ib_action :onPaste do |sender|
    @input_field.stringValue += NSPasteboard.generalPasteboard.stringForType(NSStringPboardType)
  end

  objc_method :webView_contextMenuItemsForElement_defaultMenuItems, '@@:@@@'
  def webView_contextMenuItemsForElement_defaultMenuItems(webview, dict, default_menu_items)

    # removing none useful context menu.
    my_menu_items = []
    default_menu_items.each do |item|
      if ([
          WebMenuItemTagOpenLinkInNewWindow,
          WebMenuItemTagDownloadLinkToDisk,
          WebMenuItemTagOpenImageInNewWindow,
          WebMenuItemTagDownloadImageToDisk,
          WebMenuItemTagOpenFrameInNewWindow,
          WebMenuItemTagGoBack, 
          WebMenuItemTagGoForward, 
          WebMenuItemTagStop,
          WebMenuItemTagReload, 
          WebMenuItemTagOther,
        ].include? item.tag ) then
          next
      else
        my_menu_items.push item
      end
    end

    my_menu_items
  end
end

# This code copying from LimeChat.
# 
# Created by Satoshi Nakagawa.
# You can redistribute it and/or modify it under the Ruby's license or the GPL2.
#
class MainViewPolicy < OSX::NSObject
  include OSX

  objc_method :webView_decidePolicyForNavigationAction_request_frame_decisionListener, 'v@:@@@@@'
  def webView_decidePolicyForNavigationAction_request_frame_decisionListener(sender, action, request, frame, listener)
    case action.objectForKey(WebActionNavigationTypeKey).intValue.to_i
    when WebNavigationTypeLinkClicked
      listener.ignore
      _open_url(action.objectForKey(WebActionOriginalURLKey).absoluteString)
    when WebNavigationTypeOther
      listener.use
    else
      listener.ignore
    end
  end

  def _open_url url
    urls = [ NSURL::URLWithString(url) ]
    NSWorkspace.sharedWorkspace.objc_send(:openURLs, urls,
      :withAppBundleIdentifier, nil,
      :options, NSWorkspaceLaunchAsync,
      :additionalEventParamDescriptor, nil,
      :launchIdentifiers, nil
    )
  end
end
