#!/usr/bin/ruby
#

require 'osx/cocoa'
require 'osxhotkey.so'

include OSX

class OSX::NSApplicationWithHotKey < NSApplication

	# ns_override 'sendEvent:'

	KEYMAP = {
		"0" => 0x1D, "1" => 0x12, "2" => 0x13, "3" => 0x14,
		"4" => 0x15, "5" => 0x17, "6" => 0x16, "7" => 0x1A,
		"8" => 0x1C, "9" => 0x19, "A" => 0x00, "B" => 0x0B,
		"C" => 0x08, "D" => 0x02, "E" => 0x0E, "F" => 0x03,
		"G" => 0x05, "H" => 0x04, "I" => 0x22, "J" => 0x26,
		"K" => 0x28, "L" => 0x25, "M" => 0x2E, "N" => 0x2D,
		"O" => 0x1F, "P" => 0x23, "Q" => 0x0C, "R" => 0x0F,
		"S" => 0x01, "T" => 0x11, "U" => 0x20, "V" => 0x09,
		"W" => 0x0D, "X" => 0x07, "Y" => 0x10, "Z" => 0x06,
		"=" => 0x18, "-" => 0x1B, "]" => 0x1E, "[" => 0x21,
		"RET" => 0x24, "\"" => 0x27, ";" => 0x29, "\\" => 0x2A,
		"," => 0x2B, "/" => 0x2C, "." => 0x2F, "TAB" => 0x30,
		"SPC" => 0x31, "`" => 0x32, "BS" => 0x33, "ESC" => 0x35,
	}

	def sendEvent(event) # :nodoc:
		if event.oc_type == 14 &&
	       event.subtype == 6
			@hotkey_procs ||= {}
			if @hotkey_procs[event.data1]
				@hotkey_procs[event.data1].call
			end
		end
		super_sendEvent(event)
	end

	# This method register the _keys_ as global hotkey.
	# And when the key is pressed, call the _block_. 
	#
	# _keys_ is caseinsensitive
	def register_hotkey(keys, &block)
		raise ArgumentError, "Require block." unless block_given?
		mod = 0
		key = nil
		if keys.kind_of? Numeric
			key = keys
		else
			keys.split('+').each do |k|
				k = k.upcase
				case k
				when 'SHIFT', 'CONTROL', 'COMMAND', 'OPTION'
					mod |= HotKey.const_get(k)
				else
					if KEYMAP[k]
						key = KEYMAP[k]
					else
						raise ArgumentError, "The Key #{k} is not in Map"
					end
				end
			end
			raise ArgumentError, "The Key is invalid" unless key
		end
		ref = HotKey.new(key, mod)
		id = ref.register
		@hotkey_procs ||= {}
		@hotkey_procs[id] = block
		ref
	end
end


if $0 == __FILE__
	app = NSApplicationWithHotKey.sharedApplication
#	ref = app.register_hotkey("command+shift+j") do
#		puts 'hello'
#	end
	ref = app.register_hotkey("command+`") do
		puts 'hello'
	end

	app.run
end

