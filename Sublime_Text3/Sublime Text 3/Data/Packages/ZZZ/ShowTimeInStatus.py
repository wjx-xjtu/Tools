import sublime, sublime_plugin
import time

class ShowTimeInStatusCommand(sublime_plugin.TextCommand):
	def run(self, edit):
		# view.set_status('time_msg', ' 当前时间：'+datetime.datetime.now())
		sublime.status_message(' 当前时间：'+time.strftime("%Y-%m-%d %H:%M:%S"))
