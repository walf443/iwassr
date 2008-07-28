#
#  GrowlController.rb
#  iWassr
#
#  Created by Keiji Yoshimi on 08/07/23.
#  Copyright (c) 2008 __MyCompanyName__. All rights reserved.
#

require File.expand_path(File.join(File.dirname(__FILE__), 'vendor', 'growl', 'growl.rb'))

class GrowlController
  attr_accessor :owner

  MSG_OF = {
    :reply   => 'you recieved message',
    :fav     => 'you fav message',
    :defav   => 'you defav message',
  }

  def register
    return if @growl
    @growl = Growl::Notifier.sharedInstance
    @growl.register(:iWassr, MSG_OF.values, MSG_OF.values)
  end

  def notify kind, title, desc, context=nil
    priority = :normal
    sticky = false
    if MSG_OF[kind]
      @growl.notify(MSG_OF[kind], title, desc, :click_context => context, :sticky => sticky, :priority => priority)
    end
  end
end
