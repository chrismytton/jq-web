require 'bundler/setup'
require 'sinatra'
require 'jq'
require 'net/http'
require 'yajl/json_gem'

def fetch(uri_str, limit = 10)
  fail ArgumentError, 'too many HTTP redirects' if limit == 0

  response = Net::HTTP.get_response(URI(uri_str))

  case response
  when Net::HTTPSuccess
    response
  when Net::HTTPRedirection
    location = response['location']
    warn "redirected to #{location}"
    fetch(location, limit - 1)
  else
    response.value
  end
end

get '/' do
  erb :index
end

%w(get post).each do |method|
  send method, '/jq' do
    content_type 'application/json; charset=utf-8'
    begin
      json = fetch(params[:json]).body
      jq = JQ(json)
      stream do |out|
        jq.search(params[:filter]) do |result|
          out << JSON.pretty_generate(result)
          out << "\n"
        end
      end
    rescue Net::HTTPServerException => e
      error = "Failed to fetch url #{params[:json]}: #{e}"
      logger.warn(error)
      halt 400, error
    end
  end
end
