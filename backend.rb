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

get '/?' do
  return '<h1>Restaurants API</h1>'
end

get '/restaurants/?' do
  content_type :json
  query = params[:query] || ''
  return collection.find(name: {'$regex': query, '$options': 'i'})
          .to_a.to_json
end

get '/restaurants/:id/?' do |id|
  content_type :json
  objectId = object_id_from_string id
  return {}.to_json if objectId.nil?
  restaurant = collection.find(_id: objectId).limit(1).first
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
  return ''
end

patch '/restaurants/:id/?' do |id|
  request.body.rewind
  begin
    payload = JSON.parse request.body.read
  rescue JSON::ParserError
    status 400
    return 'Invalid JSON.'
  end

  objectId = object_id_from_string id
  cuisine = payload['cuisine']
  collection.find_one_and_update({_id: objectId}, {'$set': {cuisine: cuisine}}) unless cuisine.nil?
  # TODO: Validate properly (prevent null/array or something).

  name = payload['name']
  collection.find_one_and_update({_id: objectId}, {'$set': {name: name}}) unless name.nil?
  # TODO: Validate properly.

  # TODO: Failure case.
  return ''
end

delete '/restaurants/:id/?' do |id|
  objectId = object_id_from_string id
  theDeleted = collection.find_one_and_delete(_id: objectId)
  # TODO: Failure case.
  return ''
end

post '/restaurants/:id/ratings/?' do |id|
  request.body.rewind
  begin
    payload = JSON.parse request.body.read
  rescue JSON::ParserError
    status 400
    return 'Invalid JSON.'
  end

  objectId = object_id_from_string id

  score = payload['score']
  # TODO: Validate.

  result = collection
    .find_one_and_update({_id: objectId},
      {'$push': {ratings: {date: Date.today, score: score}}})
  status 201
  return ''
end