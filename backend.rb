require 'sinatra'
require 'mongo'
require 'json/ext'

before do
  if request.request_method == 'OPTIONS'
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "POST"

    halt 200
  end
end

configure do
  collections = Mongo::Client.new(['127.0.0.1:27017'], :database => 'test')
  set :collection, collections[:restaurants]
  set :bind, '0.0.0.0'
end

get '/' do
  return '<h1>Restaurants API</h1>'
end

get '/restaurants/?' do
  content_type :json
  query = params[:query] || ''
  return collection.find(name: {'$regex': query, '$options': 'i'})
          .to_a.to_json
end

get '/restaurants/:id/?' do
  content_type :json
  return restaurant_by_id params[:id]
end

helpers do
  def collection
    return settings.collection
  end

  def restaurant_by_id id
    begin
      objectId = BSON::ObjectId.from_string(id)
    rescue BSON::ObjectId::Invalid
      return {}.to_json
    end
    return {}.to_json if objectId.nil?

    restaurant = collection.find(_id: objectId)
                  .projection(_id: false)
                  .limit(1).first
    return (restaurant || {}).to_json
  end
end

post '/restaurants/?' do
  request.body.rewind
  begin
    payload = JSON.parse request.body.read
  rescue JSON::ParserError
    status 400
    return 'Invalid JSON.'
  end

  result = collection.insert_one payload

  status 201
  response.headers['Location'] = result.inserted_id
end

patch '/restaurants/:id/?' do
  id = object_id(params[:id])
  collection.find(_id: id)
    .find_one_and_update('$set' => request.params)
  document_by_id(id)
end

# This API should be changed.
put '/update_name/:id/?' do
  content_type :json
  id = object_id(params[:id])
  name = params[:name]
  collection.find(_id: id)
    .find_one_and_update('$set' => {name: name})
  document_by_id(id)
end

delete '/restaurants/:id' do
  content_type :json
  id = object_id(params[:id])
  hits = @collection.find(_id: id)
  exists = !restaurant.to_a.first.nil?;
  hits.find_one_and_delete if exists
  { success: exists }.to_json
end