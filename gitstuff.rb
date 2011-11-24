require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'

get '/:user/:repo/search' do
  results = ElasticSearch.search params[:user], params[:repo], params[:q]
  results.inspect.to_s
end

get '/:user/:repo/:post' do
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  post = repo.post(params[:post])
  raise Sinatra::NotFound unless post
  repo.render_post post
end

post '/:user/:repo/reindex' do
  repo = Repo.find(params[:user], params[:repo])
  repo.reindex
  'ok'
end