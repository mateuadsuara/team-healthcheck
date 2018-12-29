$: << File.expand_path('lib/', File.dirname(__FILE__))
require 'web/app'

run Web::App.new
