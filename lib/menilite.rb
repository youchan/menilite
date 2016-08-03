require "menilite/version"

if RUBY_ENGINE == "opal"
  require 'menilite/model'
  require 'menilite/client/store'
else
  require 'opal'
  require 'menilite/router'
  require 'menilite/server/store'

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint
end