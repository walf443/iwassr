require File.dirname(__FILE__) + '/test_helper.rb'

class OsxhotkeyTest < Test::Unit::TestCase
	def setup
	end

	def test_load
		assert true
	end

	def test_keys
		require 'thread'

		q = SizedQueue.new(1)

		app = NSApplicationWithHotKey.sharedApplication
		assert_raise(ArgumentError) do
			app.register_hotkey("") do
			end
		end

		keytest = %w(
			Command+Shift+T
			Control+Option+T
		)

		keytest.each_with_index do |k,i|
			app.register_hotkey(k) do
				q << "OK#{i}"
			end
		end

		Thread.start do
			Thread.current.abort_on_exception = true

			keytest.each_with_index do |k,i|
				puts "Press #{k}"
				assert_equal "OK#{i}", q.pop
			end

			app.stop(nil)
		end

		app.run
	end
end
