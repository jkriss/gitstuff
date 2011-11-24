require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'

get '/:user/:repo/search' do
  results = ElasticSearch.search params[:user], params[:repo], params[:q] || params[:term]
  if results['hits']['total'] == 0
    [].to_json
  else
    posts = results['hits']['hits'].collect do |result|
      { 
        :value => "/#{params[:user]}/#{params[:repo]}/#{result['_id']}", 
        :label => result['_source']['drink_name'] 
      }
    end
    posts.to_json
  end
end

get '/:user/:repo/:post' do
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  post = repo.post(params[:post])
  repo.index_post(params[:post]) if ENV['RACK_ENV'] == 'development'
  raise Sinatra::NotFound unless post
  @search_path = "/#{repo.user}/#{repo.name}/search"
  repo.render_post post, :search_form => haml(:search_form)
end

post '/:user/:repo/reindex' do
  repo = Repo.find(params[:user], params[:repo])
  repo.reindex
  'ok'
end