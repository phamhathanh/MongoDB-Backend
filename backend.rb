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
  id = object_id_from_string params[:id]
  return {}.to_json if id.nil?

  restaurant = collection.find(_id: id).limit(1).first
  return (restaurant || {}).to_json
end

helpers do
  def collection
    return settings.collection
  end

  def object_id_from_string idString
    begin
      return BSON::ObjectId.from_string(idString)
    rescue BSON::ObjectId::Invalid
      return nil
    end
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

  payload['ratings'] = []
  result = collection.insert_one payload
  status 201
  response.headers['Location'] = result.inserted_id
end

patch '/restaurants/:id/?' do
  request.body.rewind
  begin
    payload = JSON.parse request.body.read
  rescue JSON::ParserError
    status 400
    return 'Invalid JSON.'
  end

  id = object_id_from_string params[:id]
  cuisine = payload['cuisine']
  collection.find(_id: id)
    .find_one_and_update('$set': {cuisine: cuisine})
    # TODO: Failure case.
  return ''
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