# Getting started

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'menilite'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install menilite

## How to use

You can generate the template project by [Silica](https://github.com/youchan/silica) to get started.

    $ gem install silica
    $ silica new your-app
    $ cd your-app
    $ bundle install
    $ bundle exec rackup

## Model definition

```ruby
class User < Menilite::Model
    field :name
    field :password
end
```

Model definition is shared from the client side (compiled by Opal) and the server side (in MRI).  
In this tiny example, `User` model has two string fields (`name` and `password`).  
Field has a type and the type is set `string` as default.  
You can specify another type by the following way, for example.

    field :active, :boolean

## Action

```ruby
class User < Menilite::Model
  action :signup, save: true do |password|
    self.password = BCrypt::Password.create(password)
  end
end
```

Models can have actions. The action is executed on the server side and the client code call the action as a method.

on the client side

```ruby
user = User.new(name: 'youchan')
user.auth('topsecret')
```

## Controller

Controllers can have actions too.

```ruby
class ApplicationController < Menilite::Controller
  action :login do |username, password|
    user = User.find(name: username)
    if user && user.auth(password)
      session[:user_id] = user.id
    else
      raise 'login failed'
    end
  end
end
```

The action of Controller is defined as a class method on the client side.

```ruby
ApplicationController.login('youchan', 'topsecret')
```
