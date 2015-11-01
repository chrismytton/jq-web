require 'bundler/setup'
require 'sinatra'
require 'jq'
require 'net/http'

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
      jq = JQ(json, parse_json: false)
      stream do |out|
        jq.search(params[:filter]) do |result|
          out << result
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

__END__

@@index

<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Create an API for static JSON files">
    <meta name="author" content="https://www.chrismytton.uk">
    <title>jq(1) for the web</title>
    <style>
      body {
        max-width: 600px;
        margin: 0 auto;
        padding: 10px;
        color: #444;
        font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      }
    </style>
  </head>
  <body>
    <h1>jq(1) for the web</h1>

    <form method="get" action="<%= url('/jq') %>">
      <input type="url" name="json">
      <input type="text" name="filter" placeholder=".[]|.name">
      <input type="submit" value="Query">
    </form>
  </body>
</html>
