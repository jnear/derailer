require 'webrick'

puts "Starting web server..."
puts "When it's done, please browse to http://localhost:8000"
puts ""

require 'webrick'
root = File.expand_path(File.dirname(__FILE__) + '/viz/')
cb = lambda do |req, res| 
  # req.query[:graph_string] = $graph.to_s
  # req.query[:rails_root] = Rails.root.to_s
  # req.query[:puts] = $puts
end

WEBrick::HTTPUtils::DefaultMimeTypes['rhtml'] = 'text/html'
server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => root, :RequestCallback => cb

trap 'INT' do server.shutdown end

server.start
