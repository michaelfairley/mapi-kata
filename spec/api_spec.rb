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

      DB[:users].where(:username => username).first[:password].should =~ /\A\$2a\$1\d\$[.\/A-Za-z0-9]{53}\z/
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

    it "does not create a token if the username doesn't exist"
    it "does not create a token if the password is incorrect"
  end

  describe "POST /users/:username/posts" do
    it "creates the post"
    it "doesn't create the posts if authenticated as a different user"
    it "doesn't create the post if not authenticated"
  end

  describe "GET /posts/:id" do
    it "returns the post"
  end

  describe "DELETE /posts/:id" do
    it "deletes the post"
    it "is idempotent"
    it "doesn't delete the post if authenticated as a different user than the post's author"
    it "doesn't delete the post if not authenticated"
  end

  describe "GET /users/:username/posts" do
    it "returns a sorted list of the user's most recent 50 posts"

    context "pagination" do
      it "loads subsequent pages"
      it "uses cursors properly to avoid repeats if the list has changed since the previous page load"
    end
  end

  describe "PUT /users/:username/following/:other" do
    it "follows :other"
    it "is idempotent"
    it "doesn't follow :other if authenticated in as someone other than :username"
    it "doesn't follow :other if not authenticated"
  end

  describe "DELETE /users/:username/following/:other" do
    it "unfollows :other"
    it "is idempotent"
    it "doesn't unfollow :other if authenticated in as someone other than :username"
    it "doesn't unfollow :other if not authenticated"
  end

  describe "GET /users/:username/timeline" do
    it "shows the 50 most recent posts of the users that :username is following"

    context "pagination" do
      it "loads subsequent pages"
      it "uses cursors properly to avoid repeats if the list has changed since the previous page load"
    end
  end
end
