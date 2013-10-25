require "restclient"
require "json"

class MAPI
  def self.uri(path)
    if path.start_with?("http")
      path
    else
      "http://localhost:12346#{path}"
    end
  end

  def self.create_user(details={})
    details[:username] ||= random_string(8)
    details[:password] ||= random_string(10)
    details[:real_name] ||= [random_string(8).capitalize, random_string(8).capitalize].join(" ")

    post("/users", nil, details)
  end

  def self.create_user_with_token(username)
    password = random_string(10)
    create_user(:username => username, :password => password)
    JSON.parse(MAPI.create_token(username, password).body)["token"]
  end

  def self.create_token(username, password)
    post("/tokens", nil, {:username => username, :password => password})
  end

  def self.create_post(details={})
    post(
      "/users/#{details.fetch(:username)}/posts",
      details.fetch(:token),
      :text => details.fetch(:text)
    )
  end

  def self.get_user(username)
    get_json("/users/#{username}")
  end

  def self.get_post(id)
    get_json("/posts/#{id}")
  end

  def self.get_posts(username)
    get_json("/users/#{username}/posts")
  end

  def self.get_timeline(username)
    get_json("/users/#{username}/timeline")
  end

  def self.follow(follower, followee, token)
    put("/users/#{follower}/following/#{followee}", token)
  end

  def self.unfollow(follower, followee, token)
    delete("/users/#{follower}/following/#{followee}", token)
  end

  def self.get_json(path)
    response = get(path)
    response.code.should == 200
    JSON.parse(response.body)
  end

  def self.get(path)
    url = uri(path)

    RestClient.get(url) do |response|
      response
    end
  end

  def self.post(path, token=nil, params={})
    url = uri(path)

    headers = {}
    headers["Authentication"] = "Token #{token}" if token

    RestClient.post(url, JSON.dump(params), headers) do |response|
      response
    end
  end

  def self.put(path, token=nil, params={})
    url = uri(path)

    headers = {}
    headers["Authentication"] = "Token #{token}" if token

    RestClient.put(url, JSON.dump(params), headers) do |response|
      response
    end
  end

  def self.delete(path, token=nil)
    url = uri(path)

    headers = {}
    headers["Authentication"] = "Token #{token}" if token

    RestClient.delete(url, headers) do |response|
      response
    end
  end
end
