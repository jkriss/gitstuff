require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

def get_repo_path(user, repo)
  "../drinks/"
end

def render_post(repo_path, post_name)
  path = File.join(repo_path, 'posts', params[:post]) + ".yml"
  post_data = YAML.load_file(path)
  post_data['content'] = File.read(path).sub /---.*---\n/m, ''
  post_data['content'] = RDiscount.new(post_data['content']).to_html
  
  layout = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'post.html.liquid'))
  layout.render(post_data)
end

get '/' do
  "yo."
end

get '/:user/:repo/:post' do
  repo_path = get_repo_path(params[:user], params[:repo])
  render_post repo_path, params[:post]
end