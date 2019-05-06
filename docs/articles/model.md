# Model

## How to make a model

### 1st step: Create a database migration

Create a database migration script of `ActiveRecord` to make a table for model.

```terminal
$ bundle exec rake db:create_migration create_user
```

Edit the migration file.

```ruby

```


### User privilege

```ruby
class UserPrivilege < Menilite::Privilege
  def key
    :user_privilege
  end

  def initialize(user)
    @user = user
  end

  def filter
    { user_id: @user.id }
  end

  def fields
    { user_id: @user.id }
  end
end
```
