A tiny kata I made for myself to practice building the same API with a variety of languages and libraries.

The API is for a twitteresque microblogging service that supports a handle of actions:
  - Signing up
  - Exchanging a username and password for a long lived auth token
  - Posting a message
  - Deleting messages
  - Viewing all posts for a single user (with pagination)
  - Following and unfollowing users
  - Viewing a timeline containing posts by all other users that a user is following

The API contains intentional warts in order to help determine how easy it is to break free of any given tool's opinions, because you'll always need to.

Current implementation's I've made for this kata:
- [Sinatra and Sequel](https://github.com/michaelfairley/mapi-kata-sinatra-sequel)
- [Rails::API](https://github.com/michaelfairley/mapi-kata-rails-api)
