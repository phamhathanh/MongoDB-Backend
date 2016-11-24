require 'sinatra'
require 'mongo'
require 'json/ext'

before do
  if request.request_method == 'OPTIONS'
    response.headers["Access-Control-Allow-Origin"] = '*'
    response.headers["Access-Control-Allow-Methods"] = 'POST'
    response.headers["Access-Control-Allow-Methods"] = 'PATCH'
    halt 200
  end
end

configure do
  collections = Mongo::Client.new(['127.0.0.1:27017'], :database => 'test')
  set :restaurants, collections[:restaurants]
  set :bind, '0.0.0.0'
end

get '/?' do
  return '<h1>Restaurants API</h1>'
end

get '/restaurants/?' do
  content_type :json
  query = params[:query] || ''
  return restaurants.find(name: {'$regex': query, '$options': 'i'})
          .to_a.to_json
end

get '/restaurants/:id/?' do |id|
  content_type :json

  restaurant = restaurant_by_id id
  output = restaurant.first
  return output.to_json unless output.nil?

  status 404
  return ''
end

helpers do
  def restaurants
    return settings.restaurants
  end

  def restaurant_by_id idString
    begin
      objectId = BSON::ObjectId.from_string(idString)
      return restaurants.find(_id: objectId).limit(1)
    rescue BSON::ObjectId::Invalid
      halt 400, 'Invalid ID.'
    end
  end

  def parse_json_request requestBody
    requestBody.rewind
    begin
      return JSON.parse requestBody.read
    rescue JSON::ParserError
      halt 400, 'Invalid JSON.'
    end
  end
end

post '/restaurants/?' do
  payload = parse_json_request request.body

  payload['ratings'] = []
  result = restaurants.insert_one payload
  # TODO: Validate the inserted values.

  status 201
  response.headers['Location'] = result.inserted_id
  return ''
end

patch '/restaurants/:id/?' do |id|
  restaurant = restaurant_by_id id
  payload = parse_json_request request.body

  cuisine = payload['cuisine']
  restaurant.find_one_and_update('$set': {cuisine: cuisine}) unless cuisine.nil?
  # TODO: Validate properly (prevent null/array or something).

  name = payload['name']
  restaurant.find_one_and_update('$set': {name: name}) unless name.nil?
  # TODO: Validate properly.

  # TODO: Failure case.
  return ''
end

delete '/restaurants/:id/?' do |id|
  restaurant = restaurant_by_id id
  theDeleted = restaurant.find_one_and_delete
  # TODO: Failure case.
  return ''
end

post '/restaurants/:id/ratings/?' do |id|
  restaurant = restaurant_by_id id
  payload = parse_json_request request.body

  score = payload['score']
  # TODO: Validate.

  result = restaurant.find_one_and_update('$push': {ratings: {date: Date.today, score: score}})
  status 201
  return ''
end

get '/coffee/?' do
  status 418
  return "I'm a teapot."
end