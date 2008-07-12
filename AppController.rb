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
require 'open-uri'
require 'json'
require 'erb'
Net::HTTP.version_1_2

class AppController < OSX::NSObject
  include OSX
  include ERB::Util

  OSX.require_framework 'WebKit'
  WASSR_API_BASE = URI('http://api.wassr.jp/')

  ib_outlet :window, :main_view, :input_field, :post_button, :total_view, :nick_view, :channel_view

  def awakeFromNib
    @window.alphaValue = 0.9
    @window.title = 'iWassr'
    @main_view.customUserAgent = 'iWassr/0.0.1'

    NSUserDefaults.standardUserDefaults.synchronize
    @login_id = NSUserDefaults.standardUserDefaults[:LoginID]
    @password = NSUserDefaults.standardUserDefaults[:Password]

    @policy = MainViewPolicy.alloc.init
    @main_view.policyDelegate = @policy
    
    init_loading
    NSTimer.objc_send(:scheduledTimerWithTimeInterval, 120, 
      :target, self, 
      :selector, 'update', 
      :userInfo, nil,
      :repeats, true
    )
  end

  def init_loading
    @data = _get_json
    main_body = @data.map {|status|
      warn status.inspect
      _generate_box(status)
    }.join(%Q{\n})

    html = init_html(main_body)

    @main_view.mainFrame.objc_send(:loadHTMLString, html, 
      :baseURL, NSURL.URLWithString('http://iwassr.walf443.org/')
    )

  end

  def update
    updated_items = []
    _get_json.each do |status|
      unless @data.find {|item| item['rid'] == status['rid'] }
        updated_items.push(status)
        @data.push(status)
      end
    end
    updated_body = updated_items.map {|status|
      warn status.inspect
      _generate_box(status)
    }.join(%Q{\n})

    doc = @main_view.mainFrame.DOMDocument
    if doc
      doc.body.innerHTML = doc.body.innerHTML + updated_body
    end
  end

  def _get_json
    json = []
    begin
      ( WASSR_API_BASE + "statuses/friends_timeline.json" ).open('User-Agent' => @main_view.customUserAgent, :http_basic_authentication => [ @login_id, @password ]) do |f|
        str = f.read
        json = JSON.parse(str)
      end
    rescue Exception => e
      warn e
      return []
    end
    
    return json.sort_by {|status| status['epoch'] }
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

  def _generate_box status
    time = Time.at(status['epoch'])
    # Hack for none @ mark user reply.
    msg = nil
    if ( status['reply_user_login_id'] ) 
      if ( status['html'] =~ /^@([a-zA-Z][a-zA-Z0-9]*)/ ) 
        msg = status['html'].gsub(/^@([a-zA-Z][a-zA-Z0-9]*)/) { %Q{@<a class="reply_user_login_id" href="http://wassr.jp/user/#{h status['reply_user_login_id'] }">#$1</a> } }
      else
        msg = %Q{@<a class="reply_user_link" href="http://wassr.jp/user/#{h status['reply_user_login_id'] }">#{h status['reply_user_login_id'] }</a> #{ status['html'] } }
      end
    else
      msg = status['html']
    end

    # FIXME: for avoiding emoticon, using status['text']. 
    URI.extract(h(status['text'])).each do |uri|
      msg = msg.sub(uri, %{<a class="external_link" href="#{uri}">#{uri}</a>})
    end

    str = <<-EOF_STATUS
    <div class="status" id="#{h status['rid'] }">
      <div class="user" title="#{h status['user']['screen_name'] } ( #{h status['user_login_id'] } )">
        <div class="user_icon"><img src="#{h status['user']['profile_image_url'] }" width="32" height="32"></img></div>
        <div class="user_login_id"><a href="http://wassr.jp/user/#{h status['user_login_id'] }">#{h status['user_login_id'] }</a></div>
      </div>
      <div class="message">#{ msg }</div>
      <div class="created_at" title="#{ time.strftime('%Y-%m-%d %H:%M:%S') }"><a href="#{h status['link'] }">#{ time.strftime('%H:%M:%S') }</a></div>
    </div>
    <div class="clear-both">&nbsp;</div>
    <div class="status-separetor"></div>
    EOF_STATUS
  end


  ib_action :onPost do |sender|
    @input_field.stringValue
    Net::HTTP.start(WASSR_API_BASE.host) do |http|
      req = Net::HTTP::Post.new('/statuses/update.json', { 
        'User-Agent' => @main_view.customUserAgent.to_s,
      })
      req.basic_auth @login_id, @password
      req.set_form_data({
        'source' => 'iWassr',
        'status' => @input_field.stringValue.to_s,
      })
      res = http.request req
    end
    @input_field.stringValue = ''
    update
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
