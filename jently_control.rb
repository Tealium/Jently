require 'rubygems'
require 'daemons'

pwd = Dir.pwd

Daemons.run_proc('jently.rb') do
Dir.chdir(pwd)
exec "ruby jently.rb"
end

