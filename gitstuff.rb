require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'

def partials(repo)
  @search_path = "/#{repo.user}/#{repo.name}/search"
  {
    :search_form => haml(:search_form),
    :root_path => url_prefix
  }
end

def url_prefix
  "/#{params[:user]}/#{params[:repo]}"
end

def post_url(slug)
  "#{url_prefix}/#{slug}"
end

def index
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  repo.render_index partials(repo).merge({ :url_prefix => url_prefix })
end

get '/:user/:repo/search' do
  results = ElasticSearch.search params[:user], params[:repo], params[:q] || params[:term]
  results.collect do |post|
    {
      :value => post_url(post.id), 
      :label => post.title || post.id
    }
  end.to_json
end

get '/:user/:repo/' do
  index
end

get '/:user/:repo' do
  index
end

get '/:user/:repo/:post' do
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  post = repo.post(params[:post])
  repo.index_post(params[:post]) if ENV['RACK_ENV'] == 'development'
  raise Sinatra::NotFound unless post
  repo.render_post post, partials(repo).merge({ :single_post => true })
end

post '/:user/:repo/reindex' do
  repo = Repo.find(params[:user], params[:repo])
  repo.reindex
  'ok'
end