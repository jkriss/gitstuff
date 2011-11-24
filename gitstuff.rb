require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'
require 'lib/repo'
require 'lib/post'

LOCAL_REPO_PATH = ENV['LOCAL_REPO_PATH']

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

post '/:user/:repo' do
  clone_url = request.body.read
  repo = Repo.clone(params[:user], params[:repo], clone_url)
  'ok'
end

get '/:user/:repo/info' do
  repo = Repo.find(params[:user], params[:repo])
  raise Sinatra::NotFound unless repo
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