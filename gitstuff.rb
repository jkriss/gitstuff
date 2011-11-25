require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'

LOCAL_REPO_PATH = ENV['LOCAL_REPO_PATH']
REPO_CACHE_PATH = ENV['RACK_ENV'] == 'production' ? "../../shared/repos" : "tmp/repos"

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
  repo.render_index partials(repo).merge({ :url_prefix => url_prefix }), :page => params[:page]
end

def find_repo
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
  repo
end

post '/:user/:repo' do
  clone_url = request.body.read
  repo = Repo.clone(params[:user], params[:repo], clone_url)
  'ok'
end

post '/update' do
  payload = request.body.read
  payload = JSON.parse(params[:payload])
  url = payload['repository']['url']
  puts url
  repo_path = url.sub /https?:\/\/github.com\//, ''
  user, repo_name = repo_path.split '/'
  clone_url = "git://github.com/#{user}/#{repo_name}.git"
  repo = Repo.clone(user, repo_name, clone_url)
  'ok'
end

get '/:user/:repo/info' do
  repo = find_repo
  content_type :text
  html = ""
  repo.git.commits.each do |commit|
    html += "commit #{commit.id}:  #{commit.author.inspect}, #{commit.authored_date}\n"
    # html += "#{commit.diffs}\n"
    commit.diffs.each do |diff|
      html += "#{diff.inspect}\n"
    end
    commit.tree.contents.each do |tree_or_blob|
      html += "  #{tree_or_blob.name}\n"
      if tree_or_blob.is_a? Grit::Tree
        tree_or_blob.contents.each do |blob|
            html += "    #{blob.name}\n"
        end
      end
          
    end
  end
  html
end

get '/:user/:repo/search' do
  if request.accept.include? 'text/javascript'
    results = ElasticSearch.search params[:user], params[:repo], params[:q] || params[:term]
    results.hits.collect do |post|
      {
        :value => post_url(post.id), 
        :label => post.title || post.id
      }
    end.to_json
  else
    repo = find_repo
    repo.render_collection params[:q], 
      partials(repo).merge({ :url_prefix => url_prefix }), 
      :page => params[:page],
      :search => true
  end
end

get '/:user/:repo/' do
  index
end

get '/:user/:repo' do
  index
end

get '/:user/:repo/:post' do
  repo = find_repo
  post = repo.post(params[:post])
  repo.index_post(params[:post]) if ENV['RACK_ENV'] == 'development'
  raise Sinatra::NotFound unless post
  repo.render_post post, partials(repo).merge({ :single_post => true })
end

post '/:user/:repo/reindex' do
  find_repo.reindex
  'ok'
end