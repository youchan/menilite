require "menilite/version"

require "menilite/helper"

if RUBY_ENGINE == "opal"
  require 'menilite/model'
  require 'menilite/controller'
  require 'menilite/client/store'
else
  require 'opal'
  require 'menilite/model'
  require 'menilite/controller'
  require 'menilite/privilege'
  require 'menilite/router'
  require 'menilite/server/activerecord_store'

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint
end

module Menilite
end
