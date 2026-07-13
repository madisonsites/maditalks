### Service Development Guidelines

When creating or working with service objects, follow these patterns.

**Reference Files** (example paths from a hypothetical blog application, not files in this repo):
- `app/services/blog/builders/post_builder.rb` - Example of well-structured service
- `spec/services/blog/builders/post_builder_spec.rb` - Corresponding test structure

<!-- Section Index (for selective loading — read index, then load sections by line range)
| Lines     | Section                          | Keywords                                          |
| --------- | -------------------------------- | ------------------------------------------------- |
| 20-44     | Service Structure                | Callable, initialize, call, attr_reader           |
| 46-93     | Command Extraction               | orchestration, commands, when to extract           |
| 95-177    | Avoid Callbacks                  | callbacks, after_create, service orchestration     |
| 179-213   | Dynamic Configuration            | configurable service, initialize, keyword args     |
| 215-238   | Hash Parameter Handling          | fetch, defaults, params, KeyError                 |
| 240-277   | List Organization                | alphabetize, constants, arrays, attr_reader       |
| 279-317   | Complex Conditional Logic        | descriptive variables, readability, conditionals  |
-->

### Service Structure

Use the `Callable` (`app/services/callable.rb`) pattern for service objects:

```ruby
class Blogs::Services::PostCreator
  extend Callable

  def initialize(title:, content:, author:, publish_immediately: false)
    @title = title
    @content = content
    @author = author
    @publish_immediately = publish_immediately
  end

  def call
    # main logic here
  end

  private
  # default to private attr_readers
  # alphabetize so they are easier to read through
  attr_reader :author, :content, :publish_immediately, :title
end
```

### Command Extraction

**Orchestration services are preferred** — services that coordinate multiple focused commands provide clear, readable workflows. The problem arises when individual services become overly complex with too many internal responsibilities.

**When to extract commands:**
1. **Complex business logic** (>20 lines in a single method)
2. **Multiple responsibilities** in one service method
3. **Logic that could be reused** in other contexts
4. **Methods hard to test** due to complexity
5. **State management** affecting multiple objects

**Key principle:** Extract commands when there's clear value, not just for the sake of abstraction.

```ruby
# Good - simple service that doesn't need extraction
class Blogs::Services::MarkAsRead
  def initialize(blog_post:, user:)
    @blog_post = blog_post
    @user = user
  end

  def call
    return if already_read?

    blog_post.mark_as_read_by(user)
  end

  private

  attr_reader :blog_post, :user

  def already_read?
    blog_post.read_by?(user)
  end
end

# Bad - unnecessary abstraction for simple logic
class Blogs::Services::MarkAsRead
  def call
    Posts::Commands::ValidateReadStatus.call(post: blog_post, user: user)
    Posts::Commands::UpdateReadStatus.call(post: blog_post, user: user)
    Posts::Commands::LogReadEvent.call(post: blog_post, user: user)
  end
  # When the core logic is just: blog_post.mark_as_read_by(user)
end
```

### Avoid Callbacks When Possible

**Prefer explicit service orchestration over Rails callbacks** for business logic. Callbacks make code harder to test, debug, and reason about.

**Good - explicit service orchestration:**
```ruby
# Controller
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)

    if @post.save
      Posts::Commands::SendNotifications.call(post: @post)
      Posts::Commands::UpdateSearchIndex.call(post: @post)
      Posts::Commands::TrackAnalytics.call(post: @post, event: :created)

      redirect_to @post
    else
      render :new
    end
  end
end

# Service that orchestrates multiple operations
class Posts::Commands::PublishPost
  def call
    return unless can_publish?

    post.update!(status: :published, published_at: Time.current)
    send_notifications
    update_search_index
    track_publication_analytics
  end

  private

  def send_notifications
    Posts::Commands::SendNotifications.call(post: post)
  end

  def update_search_index
    Posts::Commands::UpdateSearchIndex.call(post: post)
  end
end
```

**Bad - hidden callback logic:**
```ruby
# Model with callbacks - harder to test and debug
class Post < ApplicationRecord
  after_create :send_notifications
  after_update :update_search_index, if: :published?
  after_commit :track_analytics

  private

  def send_notifications
    NotificationService.new(self).send_to_subscribers
  end

  def update_search_index
    SearchIndexer.perform_async(id) if published?
  end
end

# Controller has no visibility into what happens
def create
  @post = Post.new(post_params)
  @post.save  # Hidden side effects happen here
end
```

**Why avoid callbacks:**
- **Explicit dependencies** - you can see what operations happen when
- **Easier testing** - test services in isolation without triggering unrelated callbacks
- **Better debugging** - clear call stack when issues arise
- **Conditional logic** - easier to add conditions around when operations should run
- **Error handling** - can handle failures from different operations appropriately
- **Performance** - avoid running expensive operations when they're not needed

**When callbacks might be acceptable:**
- **Data integrity operations** that should always happen (e.g., `before_validation :normalize_email`)
- **Simple data transformations** with no external dependencies
- **Auditing or logging** that doesn't affect business logic flow

### Dynamic Configuration Patterns

Make services flexible through configuration rather than hard-coding behavior:

```ruby
# Good - configurable service that's easy to test and reuse
class Posts::Commands::Create
  def initialize(author:, content:, notify: true, draft: true)
    @author = author
    @content = content
    @notify = notify
    @draft = draft
  end

  def call
    return processed_post if draft
    return processed_post if published_post.nil?

    notify_subscribers if notify

    published_post
  end

  private

  attr_reader :author, :content
end
```

### Hash Parameter Handling

Use `fetch` with default values instead of the `||` operator for better error handling:

```ruby
# Good - explicit about defaults and handles missing keys
def call
  blog_status = params.fetch(:status, "draft")
  blog_title = params.fetch(:title, "")
  timeout = params.fetch(:timeout, 30)
end

# Bad - silent failures for missing keys, less explicit
def call
  blog_status = params[:status] || "draft"
  blog_title = params[:title] || ""
  timeout = params[:timeout] || 30
end
```

**Why use `fetch`:**
- **Explicit defaults** - makes default values clear in the code
- **Better error handling** - raises `KeyError` for missing required keys
- **Intentional design** - forces you to think about what should happen when keys are missing

### List Organization

For arrays, constants, and other lists where order doesn't matter semantically, alphabetize for consistency:

```ruby
# Good - alphabetized for easy scanning and maintenance
VALID_LOG_LEVELS = [:debug, :error, :fatal, :info, :warn].freeze
SUPPORTED_FORMATS = ["csv", "json", "pdf", "xlsx"].freeze

def initialize(author:, content:, draft: false, notify: true, publish_at: nil)
  @author = author
  @content = content
  @draft = draft
  @notify = notify
  @publish_at = publish_at
end

# Bad - random order makes it harder to scan and maintain
VALID_LOG_LEVELS = [:info, :debug, :fatal, :warn, :error].freeze

def initialize(content:, notify: true, author:, publish_at: nil, draft: false)
  # parameters in random order
end
```

**When to alphabetize:**
- Constants with multiple values
- Method parameters (when not following a logical flow)
- Array literals with multiple string/symbol values
- Private attr_reader declarations

**When NOT to alphabetize:**
- Method calls that have logical dependencies or flow
- Parameters that follow a natural progression (e.g., `start_date:, end_date:`)
- Arrays where order has semantic meaning

### Complex Conditional Logic

Break complex `if` statements into descriptive variables for better readability:

```ruby
# Good - self-documenting variables
def preview_blog_changes
  has_content = [old_content, new_content].all?(&:present?)
  content_differs = old_content != new_content

  if has_content && content_differs
    generate_diff(old_content, new_content)
  end
end

def can_publish_blog?
  author_authorized = author.has_permission?(:publish)
  within_business_hours = Time.current.business_hours?
  system_available = !maintenance_mode?

  author_authorized && within_business_hours && system_available
end

# Bad - complex, hard-to-read conditions
def preview_blog_changes
  if old_content.present? && new_content.present? && old_content != new_content
    generate_diff(old_content, new_content)
  end
end

def can_publish_blog?
  if author.has_permission?(:publish) && Time.current.business_hours? && !maintenance_mode?
    # logic here
  end
end
```
