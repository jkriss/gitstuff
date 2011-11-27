class ElasticSearch
  include HTTParty
  base_uri 'http://localhost:9200'
  format :json
  
  def self.index_post(user, repo, slug, post_data)
    self.put "/#{user}/#{repo}/#{slug}", :body => post_data.to_json
  end
  
  def self.save_repo_metadata(user, repo, data)
    self.put "/#{user}/#{repo}/_meta", :body => (data.merge({ :hidden => true })).to_json
  end
  
  def self.repo_metadata(user, repo)
    result = self.get "/#{user}/#{repo}/_meta"
    result['_source']
  end
  
  def self.get_post(user, repo, slug)
    result = self.get "/#{user}/#{repo}/#{slug}"
    post = result['_source']
    if post
      post['id'] = result['_id']
      post
    else
      nil
    end
  end
  
  def self.search(user, repo, query, options={})
    # results = self.get "/#{user}/#{repo}/_search?q=#{query}"
    composed_query = {
      :query => {
        :query_string => {
          :query => query
        }
      }, 
      :filter => {
        :not => {
          :term => { :hidden => true }
        }
      }
    }.merge(options)
    results = self.post "/#{user}/#{repo}/_search?", :body => composed_query.to_json
    if !results['hits'] || results['hits']['total'] == 0
      Hashie::Mash.new :hits => [], :total => 0
    else
      hits = results['hits']['hits'].collect do |result|
        p = Post.new(result['_source'])
        p.id = result['_id']
        p
      end
      Hashie::Mash.new :hits => hits, :total => results['hits']['total']
    end
  end
  
  def self.clear(user, repo)
    self.delete "/#{user}/#{repo}"
  end
end