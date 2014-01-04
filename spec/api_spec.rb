require "spec_helper"

describe "Microblogging API" do
  describe "POST /users" do
    it "creates the user" do
      username = random_string(8)
      realname = random_string(8)

      response = MAPI.create_user(
        :username => username,
        :real_name => realname,
      )

      response.code.should == 303
      response.headers[:location].should == MAPI.uri("/users/#{username}")

      MAPI.get_user(username).should == {
        "username" => username,
        "real_name" => realname,
      }
    end

    it "doesn't create the user if the username already exists" do
      username = random_string(8)
      realname = random_string(8)

      response = MAPI.create_user(
        :username => username,
      )

      response.code.should == 303
      response.headers[:location].should == MAPI.uri("/users/#{username}")

      response = MAPI.create_user(
        :username => username,
      )

      response.code.should == 422
      JSON.parse(response.body).should == {
        "errors" => {
          "username" => [
            "is taken"
          ],
        },
      }
    end

    it "doesn't create the user if the password is too short" do
      username = random_string(8)
      realname = random_string(8)

      response = MAPI.create_user(
        :password => "abcd"
      )

      response.code.should == 422
      JSON.parse(response.body).should == {
        "errors" => {
          "password" => [
            "is too short"
          ],
        },
      }
    end

    it "bcrypts the password" do
      username = random_string(8)

      response = MAPI.create_user(
        :username => username,
      )

      response.code.should == 303
      response.headers[:location].should == MAPI.uri("/users/#{username}")

      DB[:users].where(:username => username).first[:password].should =~ /\A\$2a\$..\$[.\/A-Za-z0-9]{53}\z/
    end
  end

  describe "POST /token" do
    it "returns a new token for the user" do
      username = random_string(8)
      password = random_string(8)

      MAPI.create_user(
        :username => username,
        :password => password,
      )

      response = MAPI.create_token(username, password)

      response.code.should == 200
      token = JSON.parse(response.body)['token']

      DB[:tokens].where(:value => token).first['user_id'].should ==
        DB[:users].where(:username => :username).first['id']
    end

    it "does not create a token if the username doesn't exist" do
      password = random_string(8)

      MAPI.create_user(
        :password => password,
      )

      response = MAPI.create_token("junk", password)
      response.code.should == 401
    end

    it "does not create a token if the password is incorrect" do
      username = random_string(8)

      MAPI.create_user(
        :username => username,
      )

      response = MAPI.create_token(username, "junk")
      response.code.should == 401
    end
  end

  describe "POST /users/:username/posts" do
    it "creates the post" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)

      response = MAPI.create_post(
        :username => username,
        :token => token,
        :text => "This is a message!",
      )

      response.code.should == 303
      post_id = response.headers[:location][/\d+\z/]

      post = MAPI.get_post(post_id)

      post['text'].should == "This is a message!"
      post['author'].should == username
    end

    it "doesn't create the posts if authenticated as a different user" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)

      response = MAPI.create_post(
        :username => "different",
        :token => token,
        :text => "This is a message!",
      )

      response.code.should == 403
    end

    it "doesn't create the post if not authenticated" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)

      response = MAPI.create_post(
        :username => username,
        :token => "wrong token",
        :text => "This is a message!",
      )

      response.code.should == 401
    end
  end

  describe "GET /posts/:id" do
    it "404s if the post doesn't exist" do
      response = MAPI.get("/posts/123456")
      response.code.should == 404
    end
  end

  describe "DELETE /posts/:id" do
    it "deletes the post" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)

      response = MAPI.create_post(
        :username => username,
        :token => token,
        :text => "This is a message!",
      )

      response.code.should == 303

      delete_response = MAPI.delete(response.headers[:location], token)
      delete_response.code.should == 204

      MAPI.get(response.headers[:location]).code.should == 404
    end

    it "404s for non-existant posts" do
      username = random_string(8)
      token = MAPI.create_user_with_token(username)

      delete_response = MAPI.delete("/posts/820123", token)
      delete_response.code.should == 404
    end

    it "doesn't delete the post if authenticated as a different user than the post's author" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)
      token2 = MAPI.create_user_with_token(random_string(9))

      response = MAPI.create_post(
        :username => username,
        :token => token,
        :text => "This is a message!",
      )

      response.code.should == 303

      delete_response = MAPI.delete(response.headers[:location], token2)
      delete_response.code.should == 403

      MAPI.get(response.headers[:location]).code.should == 200
    end

    it "doesn't delete the post if not authenticated" do
      username = random_string(8)

      token = MAPI.create_user_with_token(username)

      response = MAPI.create_post(
        :username => username,
        :token => token,
        :text => "This is a message!",
      )

      response.code.should == 303

      delete_response = MAPI.delete(response.headers[:location])
      delete_response.code.should == 401

      MAPI.get(response.headers[:location]).code.should == 200
    end
  end

  describe "GET /users/:username/posts" do
    it "returns a sorted list of the user's most recent 50 posts" do
      username = random_string(8)
      token = MAPI.create_user_with_token(username)

      post_ids = 51.times.map do
        response = MAPI.create_post(
          :username => username,
          :token => token,
          :text => "This is a message!",
          )

        response.code.should == 303
        response.headers[:location][/\d+\z/].to_i
      end.reverse

      posts = MAPI.get_posts(username)["posts"]

      posts.map{ |p| p['id'] }.should == post_ids.first(50)
    end

    it "404s if the user doesn't exist" do
      response = MAPI.get("/users/nonexistant/posts")
      response.code.should == 404
    end

    context "pagination" do
      it "loads subsequent pages" do
        username = random_string(8)
        token = MAPI.create_user_with_token(username)

        post_ids = 51.times.map do
          response = MAPI.create_post(
            :username => username,
            :token => token,
            :text => "This is a message!",
            )

          response.code.should == 303
          response.headers[:location][/\d+\z/].to_i
        end.reverse

        next_url = MAPI.get_posts(username)["next"]

        posts = JSON.parse(MAPI.get(next_url))["posts"]
        posts.map{ |p| p['id'] }.should == [post_ids.last]
      end

      it "uses cursors properly to avoid repeats if the list has changed since the previous page load" do
        username = random_string(8)
        token = MAPI.create_user_with_token(username)

        post_ids = 53.times.map do
          response = MAPI.create_post(
            :username => username,
            :token => token,
            :text => "This is a message!",
            )

          response.code.should == 303
          response.headers[:location][/\d+\z/].to_i
        end.reverse

        next_url = MAPI.get_posts(username)["next"]

        (post_ids.first(51) + [post_ids.last]).each do |pid|
          delete_response = MAPI.delete("/posts/#{pid}", token)
          delete_response.code.should == 204
        end

        posts = JSON.parse(MAPI.get(next_url))["posts"]
        posts.map{ |p| p['id'] }.should == [post_ids[51]]
      end
    end
  end

  describe "PUT /users/:username/following/:other" do
    it "follows :other" do
      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)
    end

    it "is idempotent" do
      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)
    end

    it "doesn't follow :other if authenticated in as someone other than :username" do
      other = random_string(8)
      token = MAPI.create_user_with_token(other)

      follower = random_string(8)
      MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 403

      MAPI.get_user(followee)["followers"].should_not include(follower)
      MAPI.get_user(follower)["following"].should_not include(followee)
    end

    it "doesn't follow :other if not authenticated" do
      follower = random_string(8)
      MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, "bogus")
      response.code.should == 401

      MAPI.get_user(followee)["followers"].should_not include(follower)
      MAPI.get_user(follower)["following"].should_not include(followee)
    end
  end

  describe "DELETE /users/:username/following/:other" do
    it "unfollows :other" do
      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)

      response = MAPI.unfollow(follower, followee, token)
      response.code.should == 204

      MAPI.get_user(followee)["followers"].should_not include(follower)
      MAPI.get_user(follower)["following"].should_not include(followee)
    end

    it "404s if the followership doesn't exist" do
      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)

      response = MAPI.unfollow(follower, followee, token)
      response.code.should == 204

      response = MAPI.unfollow(follower, followee, token)
      response.code.should == 404

      MAPI.get_user(followee)["followers"].should_not include(follower)
      MAPI.get_user(follower)["following"].should_not include(followee)
    end

    it "doesn't unfollow :other if authenticated in as someone other than :username" do
      other = random_string(8)
      other_token = MAPI.create_user_with_token(other)

      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)

      response = MAPI.unfollow(follower, followee, other_token)
      response.code.should == 403

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)
    end

    it "doesn't unfollow :other if not authenticated" do
      follower = random_string(8)
      token = MAPI.create_user_with_token(follower)

      followee = random_string(8)
      MAPI.create_user_with_token(followee)

      response = MAPI.follow(follower, followee, token)
      response.code.should == 201

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)

      response = MAPI.unfollow(follower, followee, "junk")
      response.code.should == 401

      MAPI.get_user(followee)["followers"].should include(follower)
      MAPI.get_user(follower)["following"].should include(followee)
    end
  end

  describe "GET /users/:username/timeline" do
    it "shows the 50 most recent posts of the users that :username is following" do
      user1 = random_string(8)
      token1 = MAPI.create_user_with_token(user1)
      user2 = random_string(8)
      token2 = MAPI.create_user_with_token(user2)
      user3 = random_string(8)
      token3 = MAPI.create_user_with_token(user3)

      post_ids = 51.times.map do |i|
        user, token = [[user1, token1], [user2, token2], [user3, token3]][i%3]

        response = MAPI.create_post(
          :username => user,
          :token => token,
          :text => "This is a message!",
          )

        response.code.should == 303
        response.headers[:location][/\d+\z/].to_i
      end.reverse

      follower = random_string(8)
      follower_token = MAPI.create_user_with_token(follower)

      response = MAPI.follow(follower, user1, follower_token)
      response = MAPI.follow(follower, user2, follower_token)
      response = MAPI.follow(follower, user3, follower_token)

      posts = MAPI.get_timeline(follower)["posts"]

      posts.map{ |p| p['id'] }.should == post_ids.first(50)
    end

    context "pagination" do
      it "loads subsequent pages" do
        user1 = random_string(8)
        token1 = MAPI.create_user_with_token(user1)
        user2 = random_string(8)
        token2 = MAPI.create_user_with_token(user2)
        user3 = random_string(8)
        token3 = MAPI.create_user_with_token(user3)

        post_ids = 51.times.map do |i|
          user, token = [[user1, token1], [user2, token2], [user3, token3]][i%3]

          response = MAPI.create_post(
            :username => user,
            :token => token,
            :text => "This is a message!",
            )

          response.code.should == 303
          response.headers[:location][/\d+\z/].to_i
        end.reverse

        follower = random_string(8)
        follower_token = MAPI.create_user_with_token(follower)

        response = MAPI.follow(follower, user1, follower_token)
        response = MAPI.follow(follower, user2, follower_token)
        response = MAPI.follow(follower, user3, follower_token)

        next_url = MAPI.get_timeline(follower)["next"]

        posts = JSON.parse(MAPI.get(next_url))["posts"]
        posts.map{ |p| p['id'] }.should == [post_ids.last]
      end

      it "uses cursors properly to avoid repeats if the list has changed since the previous page load" do
        user1 = random_string(8)
        token1 = MAPI.create_user_with_token(user1)
        user2 = random_string(8)
        token2 = MAPI.create_user_with_token(user2)
        user3 = random_string(8)
        token3 = MAPI.create_user_with_token(user3)

        post_ids = 53.times.map do |i|
          user, token = [[user1, token1], [user2, token2], [user3, token3]][i%3]

          response = MAPI.create_post(
            :username => user,
            :token => token,
            :text => "This is a message!",
            )

          response.code.should == 303
          [response.headers[:location][/\d+\z/].to_i, token]
        end.reverse

        follower = random_string(8)
        follower_token = MAPI.create_user_with_token(follower)

        response = MAPI.follow(follower, user1, follower_token)
        response = MAPI.follow(follower, user2, follower_token)
        response = MAPI.follow(follower, user3, follower_token)

        next_url = MAPI.get_timeline(follower)["next"]

        (post_ids.first(51) + [post_ids.last]).each do |pid, token|
          delete_response = MAPI.delete("/posts/#{pid}", token)
          delete_response.code.should == 204
        end

        posts = JSON.parse(MAPI.get(next_url))["posts"]
        posts.map{ |p| p['id'] }.should == [post_ids[51][0]]
      end
    end
  end
end
