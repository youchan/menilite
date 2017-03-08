require "menilite/version"

require "menilite/helper"

if RUBY_ENGINE == "opal"
  require 'native'
  require 'menilite/model'
  require 'menilite/controller'
  require 'menilite/client/http'
  require 'menilite/client/deserializer'
  require 'menilite/client/store'
else
  require 'opal'
  require 'menilite/model'
  require 'menilite/controller'
  require 'menilite/server/error_with_status_code'
  require 'menilite/server/privilege'
  require 'menilite/server/serializer'
  require 'menilite/server/router'
  require 'menilite/server/activerecord_store'

  Opal.append_path File.expand_path('../', __FILE__).untaint
  Opal.append_path File.expand_path('../../vendor', __FILE__).untaint
end

module Menilite
end
