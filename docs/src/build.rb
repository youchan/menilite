require "haml"
require "psych"
require "redcarpet"

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                                   autolink: true,
                                   tables: true,
                                   fenced_code_blocks: true)

haml = File.read(File.expand_path("../views/index.haml", __dir__))
list = Psych.load_file(File.expand_path("../articles/list.yaml", __dir__))

titles, contents = list.each_with_object([[], []]) do |name, (titles, contents)|
  md = File.read(File.expand_path("../articles/#{name}", __dir__))
  titles << md.split("\n").first.sub(/^\# (.*)/, '\\1')
  contents << markdown.render(md)
end

File.open(File.expand_path("../index.html", __dir__), "w") do |out|
  out << Haml::Engine.new(haml, :format => :html5).render(Object.new, {titles: titles, contents: contents})
end
