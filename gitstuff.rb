require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'digest/md5'
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'
require 'lib/cloner'
require 'lib/indexer'
require 'lib/api_key_manager'

LOCAL_REPO_PATH = ENV['LOCAL_REPO_PATH']
REPO_CACHE_PATH = ENV['RACK_ENV'] == 'production' ? "../../shared/repos" : "tmp/repos"

use Rack::Cache, :entitystore => 'file:tmp/cache/rack/body'

def partials(repo)
  @search_path = "/#{repo.user}/#{repo.name}/search"
  {
    :search_form => haml(:search_form),
    :root_path => url_prefix,
    :asset_path => "#{url_prefix}/assets"
  }
end

def url_prefix
  request_url = request.url
  # hack. there should be a good way to figure this out from headers
  request_url.sub!(':8080','') 
  "#{request_url.match(/(^.*\/{2}[^\/]*)/)[1]}/#{params[:user]}/#{params[:repo]}"
end

def post_url(slug)
  "#{url_prefix}/#{slug}"
end

def index
  repo = find_repo
  raise Sinatra::NotFound unless repo
  repo.render_index partials(repo).merge({ :url_prefix => url_prefix }), 
    :page => params[:page], 
    :template => @template
end

def find_repo
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  cache_control :public
  puts "#{request.url}-#{repo.commit_hash}"
  etag Digest::MD5.hexdigest("#{request.url}-#{repo.commit_hash}")
  repo
end

error 404 do
  haml :not_found, :layout => :gitstuff_layout
end

get '/' do
  haml :index, :layout => :gitstuff_layout
end

get '/:user/:repo/assets/*' do
  # https://github.com/jkriss/drinks/raw/master/assets/favicon.ico
  asset_path = params[:splat].join "/"
  redirect "https://github.com/#{params[:user]}/#{params[:repo]}/raw/master/assets/#{asset_path}"
end

post '/update/:api_key' do
  payload = request.body.read
  payload = JSON.parse(params[:payload])
  url = payload['repository']['url']
  repo_path = url.sub /https?:\/\/github.com\//, ''
  user, repo_name = repo_path.split '/'
  clone_url = "git://github.com/#{user}/#{repo_name}.git"
  # make sure the api key matches
  return 403 unless ApiKeyManager.valid_key? params[:api_key], clone_url
  repo = Repo.clone(user, repo_name, clone_url)
  'ok'
end

get '/:user/:repo/search' do
  repo = find_repo
  if request.accept.include? 'text/javascript'
    results = ElasticSearch.search params[:user], params[:repo], params[:q] || params[:term]
    results.hits.collect do |post|
      {
        :value => post_url(post.id), 
        :label => post.title || post.id
      }
    end.to_json
  else
    repo.render_collection params[:q], 
      partials(repo).merge({ :url_prefix => url_prefix }), 
      :page => params[:page],
      :search => true
  end
end

get '/:user/:repo/' do
  index
end

get '/:user/:repo/atom.xml' do
  # content_type "application/atom+xml"
  @template = "atom.xml.liquid"
  index
end

get '/:user/:repo' do
  index
end

get '/:user/:repo/:post' do
  repo = find_repo
  
  if params[:post].include? ':'
    filter_attribute, filter_value = params[:post].split ':'
    repo.render_collection "#{filter_attribute}:#{filter_value}", 
      partials(repo).merge({ :url_prefix => url_prefix }), 
      :page => params[:page]
  else
    post = repo.post(params[:post])
    raise Sinatra::NotFound unless post
    repo.render_post post, partials(repo).merge({ :single_post => true })
  end
end

post '/:user/:repo/reindex' do
  find_repo.reindex
  'ok'
end