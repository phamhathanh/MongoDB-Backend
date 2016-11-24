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
  return ''
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
  collection.find_one_and_update({_id: id}, {'$set': {cuisine: cuisine}}) unless cuisine.nil?

  name = payload['name']
  collection.find_one_and_update({_id: id}, {'$set': {name: name}}) unless name.nil?

  # TODO: Failure case.
  # TODO: Validate (prevent array or something).
  return ''
end

delete '/restaurants/:id/?' do
  id = object_id_from_string params[:id]
  theDeleted = collection.find_one_and_delete(_id: id)
    # TODO: Failure case.
  return ''
end

post '/restaurants/:id/ratings/?' do
  request.body.rewind
  begin
    payload = JSON.parse request.body.read
  rescue JSON::ParserError
    status 400
    return 'Invalid JSON.'
  end

  id = object_id_from_string params[:id]

  score = payload['score']
  # TODO: Validate.

  result = collection.find_one_and_update({_id: id}, {'$push': {ratings: {date: Date.today, score: score}}})
  status 201
  return ''
end