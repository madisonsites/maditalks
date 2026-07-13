# Testing Guidelines

When creating tests, please follow these guidelines.

Reference File: `spec/services/blog/builders/post_builder_spec.rb` provides a good example of ideal test structure.

<!-- Section Index (for selective loading — read index, then load sections by line range)
| Lines      | Section                          | Keywords                                          |
| ---------- | -------------------------------- | ------------------------------------------------- |
| 16-80      | What Not to Test                 | language features, framework functionality        |
| 81-300     | Stubbing Guidelines              | external services, internal stubs, let overrides  |
| 301-475    | Factory and Object Creation      | FactoryBot, traits, transients, let!, minimize    |
| 476-615    | Test Organization                | private methods, positive/negative, progressive   |
| 616-780    | Parameterization and Contexts    | let, time management, shared_context, shared      |
| 781-850    | Assertions and Expectations      | match_array, have_attributes, change              |
| 851-920    | Test Structure                   | method notation, one subject, describe blocks     |
| 921-970    | TDD and JSON Patterns            | failing tests first, hash keys, splat             |
| 971-1050   | Common Issues and Rules          | duplicates, agent checklist, cleanup protocol     |
-->

## What Not to Test: Focus on Business Logic, Not Language Features

DO NOT test basic Ruby/Rails language functionality. Focus on testing your business logic and application behavior.

**DO NOT test these language features:**
- Parameter validation (missing arguments, ArgumentError)
- Ruby method call mechanics
- Rails framework functionality (ActiveRecord validations, callbacks)
- Basic object instantiation
- Nil handling that's part of Ruby language behavior

**TDD Rule: Tests should fail because expected behavior doesn't happen, not because of implementation errors.**

```ruby
# Good TDD approach - tests fail on missing behavior
def call
  # Empty implementation - let behavioral tests fail naturally
end

it "creates blog post with published status" do
  expect { subject }.to change { BlogPost.published.count }.by(1)
  # Fails because: expected 1 change, got 0 (no blog post created)
end

it "returns true when successful" do
  expect(subject).to be true
  # Fails because: expected true, got nil (empty method returns nil)
end

# Bad - testing implementation errors during TDD
def call
  raise NotImplementedError, "Not implemented yet"
end

it "raises NotImplementedError during setup" do
  expect { subject }.to raise_error(NotImplementedError)
  # This test will be deleted once implemented - wasteful
end

# Bad - testing Ruby language functionality
it "raises ArgumentError when blog is missing" do
  expect { described_class.call(author: author) }.to raise_error(ArgumentError)
end

# Good - testing business logic and application behavior
it "returns false when blog post cannot be published" do
  expect(subject).to be_falsey
end

it "creates blog post with custom title" do
  expect { subject }.to change { BlogPost.published.count }.by(1)
end
```

**Focus your tests on:**
- Business logic and rules
- Data changes and state transitions
- Integration between your services
- External service interactions
- Application-specific behavior

## Stubbing Guidelines: What to Stub and What Not to Stub

DO NOT stub internal methods, models, or basic Ruby/Rails functionality. Use real factories and database objects instead.

**ONLY stub these dependencies:**

### External Services:
- Background job workers (Sidekiq, etc.)
- Email delivery (mailers)
- Third-party API calls
- Feature flags
- External HTTP requests

### Other Services/Commands/Queries (within same repo):
- Other service objects that the service under test calls
- Command objects that the service orchestrates
- Query objects that the service depends on

```ruby
# Good - stubbing external services
allow(SomeWorker).to receive(:perform_async)
allow(UserMailer).to receive(:deliver_now)
allow(FeatureFlag).to receive(:enabled?).and_return(true)

# Good - stubbing other services/commands/queries within the repo
allow(Blogs::Queries::PublishedPostsQuery).to receive(:call).and_return(posts)
allow(Blogs::Commands::SendNotification).to receive(:call)

# Bad - stubbing internal methods/models or Ruby/Rails functionality
allow(user).to receive(:some_method)
allow(User).to receive(:find).and_return(user)
allow(ActiveRecord::Base).to receive(:transaction)
```

### Stub Once, Override with Let Variables

When stubbing internal services, **stub once in a `before` block** and use `let` variables to make return values configurable:

```ruby
# Good - flexible stubbing pattern with object arrays
RSpec.describe Blogs::Commands::PublishPost do
  let(:blog_post) { create(:blog_post) }
  let(:related_posts) { [] }
  let(:notification_result) { true }

  before do
    allow(Blogs::Queries::RelatedPostsQuery).to receive(:call)
      .and_return(BlogPost.where(id: related_posts.map(&:id)))
    allow(Blogs::Commands::SendNotification).to receive(:call).and_return(notification_result)
  end

  subject { described_class.call(blog_post: blog_post) }

  context "when blog post has related content" do
    let!(:related_posts) { create_list(:blog_post, 3) }

    it "includes related posts in the response" do
      expect(subject.related_posts).to match_array(related_posts)
    end

    context "and notification fails" do
      let(:notification_result) { false }

      it "handles notification failure gracefully" do
        expect(subject).to be_successful
        expect(subject.warnings).to include("Notification failed")
      end
    end
  end

  context "when blog post has no related content" do
    it "returns empty related posts" do
      expect(subject.related_posts).to be_empty
    end
  end
end

# Bad - multiple stub definitions
RSpec.describe Blogs::Commands::PublishPost do
  context "when blog post has related content" do
    before do
      allow(Blogs::Queries::RelatedPostsQuery).to receive(:call)
        .and_return(create_list(:blog_post, 2))
    end
  end

  context "when blog post has no related content" do
    before do
      allow(Blogs::Queries::RelatedPostsQuery).to receive(:call)
        .and_return([])
    end
  end
end
```

### Avoid `anything` Matcher - Use Specific Expectations

**NEVER use `anything` in test expectations** — it indicates you're not testing specific behavior.

```ruby
# Bad - using anything is a code smell
it "calls notification service" do
  expect(Posts::Commands::NotifySubscribers).to receive(:call).with(post_id: anything)
  subject
end

# Good - be specific about expected values using have_received
it "calls notification service with created blog post" do
  allow(Posts::Commands::NotifySubscribers).to receive(:call)

  subject

  created_post = BlogPost.last
  expect(Posts::Commands::NotifySubscribers).to have_received(:call).with(post_id: created_post.id)
end
```

**Better patterns (in order of preference):**
1. Use `have_received` after the action — allows inspecting actual created objects
2. Separate tests — test object creation separately from service calls
3. Type/range checks as last resort — only when `have_received` isn't feasible

## Factory and Object Creation Patterns

### Minimize Object Creation

```ruby
# Good - use `build` when you don't need persistence
let(:author) { build(:user) }

# Good - use `create` only when persistence is required
let!(:author) { create(:user) }

# Bad - creating unnecessary objects
let!(:author) { create(:user) }  # When `build(:user)` would suffice
```

### Use Traits and Transients for Optional Associations

Keep factories minimal by default:

```ruby
# Good - minimal factory with optional association traits
FactoryBot.define do
  factory :author do
    name { "Jane Doe" }
    email { "jane@example.com" }

    trait :with_posts do
      transient do
        posts_count { 1 }
      end

      after(:create) do |author, evaluator|
        create_list(:post, evaluator.posts_count, author: author)
      end
    end

    trait :admin do
      role { :admin }
    end
  end
end

# Usage in tests:
let(:author) { create(:author) }
let(:author_with_posts) { create(:author, :with_posts) }
let(:author_with_many_posts) { create(:author, :with_posts, posts_count: 3) }

# Bad - creating unnecessary associations by default
FactoryBot.define do
  factory :author do
    name { "Jane Doe" }
    posts { create_list(:post, 3) }  # Creates posts even when not needed
  end
end
```

### Advanced Transient Patterns

**Use top-level transients to automatically apply traits** for common test patterns:

```ruby
# Excellent - top-level transient that auto-applies traits
FactoryBot.define do
  factory :post do
    blog
    author

    transient do
      for_categories { [] }
    end

    after(:create) do |post, evaluator|
      if evaluator.for_categories.any?
        post.post_categories = evaluator.for_categories.map.with_index do |category, index|
          create(:post_category,
            post: post,
            category: category,
            category_type: category.category_type,
            name: category.category_type.name,
            value: category.value,
            priority: index + 1
          )
        end
      end
    end

    trait :with_categories do
      transient do
        categories { create_list(:category, 2) }
      end
      for_categories { categories }
    end
  end
end

# Usage - extremely clean test setup:
let(:category) { create(:category) }
let(:post) { create(:post, for_categories: [category]) }
```

### Don't Create Separate Contexts for Factory Features

```ruby
# Bad - separate context just for transients
context "when using factory transients" do
  let!(:object) { create(:model, transient_param: value) }

  it "demonstrates transient usage" do
    # Test focused on transient rather than business logic
  end
end

# Good - use transients within business logic contexts
context "when processing orders from specific locations" do
  let!(:test_location) { create(:location) }
  let!(:order) { create(:order, location: test_location) }

  it "applies location-specific business rules" do
    # Test focuses on business logic that benefits from location data
  end
end
```

### Use let! for Test Data, Not Inline Creation

```ruby
# Good - reusable test data with let!
RSpec.describe Blogs::Commands::PublishPost do
  let!(:blog) { create(:blog) }
  let!(:subscribers) { create_list(:user, 2) }
  let!(:blog_post) { create(:blog_post, blog: blog, status: post_status) }

  subject { described_class.call(blog_post: blog_post) }

  context "when post is ready for publishing" do
    let(:post_status) { :ready }

    it "publishes the post" do
      expect { subject }.to change { blog_post.reload.status }.to("published")
    end

    it "notifies all subscribers" do
      expect { subject }.to change { Notification.count }.by(2)
    end
  end

  context "when post is not ready" do
    let(:post_status) { :draft }

    it "does not publish the post" do
      expect { subject }.not_to change { blog_post.reload.status }
    end
  end
end

# Bad - creating objects within it blocks
RSpec.describe Blogs::Commands::PublishPost do
  context "when post is ready for publishing" do
    it "publishes the post" do
      blog = create(:blog)
      blog_post = create(:blog_post, blog: blog, status: :ready)

      expect { subject }.to change { blog_post.reload.status }.to("published")
    end

    it "notifies all subscribers" do
      blog = create(:blog)
      blog_post = create(:blog_post, blog: blog, status: :ready)
      subscribers = create_list(:user, 2)

      expect { subject }.to change { Notification.count }.by(2)
    end
  end
end
```

## Test Structure and Organization

### Never Test Private Methods Directly

```ruby
# Bad - testing private methods directly
describe "#create_blog_notifications" do
  let(:instance) { described_class.new(blog: blog, author: author) }

  it "sends notifications to subscribers" do
    expect { instance.send(:create_blog_notifications) }
      .to change { Notification.count }.by(2)
  end
end

# Good - test behavior through public interface
describe "#call" do
  let!(:subscribers) { create_list(:user, 2) }

  it "sends notifications to subscribers" do
    expect { subject }
      .to change { Notification.count }.by(2)
  end

  it "marks notifications as pending" do
    subject
    expect(Notification.last(2)).to all(have_attributes(status: "pending"))
  end
end
```

### Test Both Positive and Negative Scenarios

```ruby
# Good - comprehensive positive and negative testing
context "when blog post is valid" do
  let(:blog_status) { :published }

  it "creates the blog post successfully" do
    expect { subject }.to change { BlogPost.count }.by(1)
  end

  it "sends notification to subscribers" do
    expect(NotificationWorker).to receive(:perform_async)
      .with(blog_post.id)
    subject
  end
end

context "when blog post is invalid" do
  let(:blog_status) { :draft }

  it "does not create the blog post" do
    expect { subject }.not_to change { BlogPost.count }
  end

  it "does not send notifications" do
    expect(NotificationWorker).not_to receive(:perform_async)
    subject
  end
end
```

### Progressive Setup - Keep Variables Close to Where They're Used

```ruby
# Good - progressive setup as you need it
RSpec.describe Posts::Commands::PublishPost do
  let(:post) { create(:post) }

  subject { described_class.call(post: post) }

  context "when post publishing succeeds" do
    it "marks post as published" do
      expect { subject }.to change { post.reload.status }.to("published")
    end
  end

  context "when post requires review" do
    let(:review_service_result) { { approved: true, feedback: "looks good" } }

    before do
      allow(Posts::Commands::Review).to receive(:call).and_return(review_service_result)
    end

    context "and review is approved" do
      let(:review_service_result) { { approved: true, feedback: "approved" } }

      it "publishes with review approval" do
        expect(subject).to be_successful
      end
    end

    context "and review is rejected" do
      let(:review_service_result) { { approved: false, feedback: "needs work" } }

      it "handles the rejection gracefully" do
        expect(subject).to be_failure
      end
    end
  end
end

# Bad - defining everything at the top even when not needed
RSpec.describe Posts::Commands::Publish do
  let(:post) { create(:post) }
  let(:review_service_result) { { approved: true } }

  before do
    allow(Posts::Commands::Review).to receive(:call).and_return(review_service_result)
  end
end
```

### Avoid Updating Objects in Before Blocks

```ruby
# Good - use let variables with factory attributes/traits
RSpec.describe Blogs::Commands::PublishPost do
  let(:post_status) { :draft }
  let(:blog_post) { create(:blog_post, status: post_status, blog: blog) }

  subject { described_class.call(blog_post: blog_post) }

  context "when blog post is already published" do
    let(:post_status) { :published }

    it "returns false without processing" do
      expect(subject).to be_falsey
    end
  end
end

# Bad - updating objects in before blocks
RSpec.describe Blogs::Commands::PublishPost do
  let(:blog_post) { create(:blog_post, blog: blog) }

  context "when blog post is already published" do
    before { blog_post.update!(status: :published) }  # Avoid doing this

    it "returns false without processing" do
      expect(subject).to be_falsey
    end
  end
end
```

**Never hardcode database IDs** — use natural ID generation and test actual sorting behavior instead.

## Parameterization and Contexts

### Smart Parameterization with Let

**ALWAYS parameterize values that get overridden in child contexts:**

```ruby
# Good - parameterize attributes that change across contexts
RSpec.describe BlogPost do
  describe "#published?" do
    subject { blog_post.published? }

    let(:blog_post) { create(:blog_post, status: post_status) }

    context "when post is published" do
      let(:post_status) { :published }
      it { is_expected.to eq(true) }
    end

    context "when post is draft" do
      let(:post_status) { :draft }
      it { is_expected.to eq(false) }
    end

    context "when post is archived" do
      let(:post_status) { :archived }
      it { is_expected.to eq(false) }
    end
  end
end

# Bad - creating separate objects for each context
RSpec.describe BlogPost do
  describe "#published?" do
    context "when post is published" do
      let(:blog_post) { create(:blog_post, status: :published) }
      it { is_expected.to eq(true) }
    end

    context "when post is draft" do
      let(:blog_post) { create(:blog_post, status: :draft) }
      it { is_expected.to eq(false) }
    end
  end
end
```

### Time Management Pattern

```ruby
# Good - parameterized time that can be overridden
RSpec.describe Blog::Services::SchedulePost do
  subject { described_class.call(post: post, scheduled_at: scheduled_time) }

  let(:current_time) { Time.zone.parse("2023-12-15 14:30:00 UTC") }
  let(:scheduled_time) { current_time + 1.hour }
  let(:post) { create(:post, status: post_status) }
  let(:post_status) { :draft }

  around { |example| Timecop.freeze(current_time) { example.run } }

  context "when scheduling for immediate publication" do
    let(:scheduled_time) { current_time }

    it "publishes the post immediately" do
      expect { subject }.to change { post.reload.status }.to("published")
    end
  end

  context "when scheduling for future publication" do
    let(:scheduled_time) { current_time + 2.days }

    it "keeps post as scheduled" do
      expect { subject }.to change { post.reload.status }.to("scheduled")
    end
  end
end
```

### Shared Context for Common Dependencies

**Use nested contexts within a single describe block:**

```ruby
# Good - shared parent context
RSpec.describe Comment do
  describe "#related_post" do
    subject { comment.related_post }

    let(:comment) { build(:comment) }

    context "when comment has a post" do
      let(:post) { create(:post) }

      context "through direct post association" do
        let(:comment) { build(:comment, post: post) }

        it "returns the post from direct association" do
          expect(subject).to eq(post)
        end
      end

      context "through category association" do
        let(:comment) { build(:comment, category: category) }

        context "with post-linked category" do
          let(:category) { create(:category, post: post) }

          it "returns the post from category association" do
            expect(subject).to eq(post)
          end
        end
      end
    end

    context "when comment has no post associations" do
      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end
end
```

**Use RSpec shared context for cross-describe-block reuse:**

```ruby
# Good - shared context for optional configuration
RSpec.describe Blog::Services::Publisher do
  let(:blog) { create(:blog) }
  let(:service) { described_class.new }

  shared_context "with currency exchange rates" do
    before(:each) do
      @old_default_bank = Money.default_bank
      store = Money::RatesStore::Memory.new
      store.add_rate("EUR", "USD", 1.25)
      store.add_rate("USD", "EUR", 0.8)
      Money.default_bank = Money::Bank::VariableExchange.new(store)
    end

    after(:each) do
      Money.default_bank = @old_default_bank
    end
  end

  describe "#publish_post" do
    it "marks post as published" do
      expect { service.publish_post(post) }.to change { post.reload.status }.to("published")
    end
  end

  describe "#calculate_author_earnings" do
    include_context "with currency exchange rates"

    let(:author) { create(:author, payment_currency: "EUR") }
    let(:post) { create(:post, blog: blog, author: author, revenue: Money.new(100_00, "USD")) }

    it "converts USD revenue to author's EUR currency" do
      earnings = service.calculate_author_earnings(post)
      expect(earnings).to eq(Money.new(80_00, "EUR"))
    end
  end
end
```

## Assertions and Expectations

### Use match_array with have_attributes for Collections

```ruby
# Good
expect(result).to match_array([
  have_attributes(title: "First Post", status: "published"),
  have_attributes(title: "Second Post", status: "draft")
])

# Bad
expect(result.count).to eq(2)
expect(result.first.title).to eq("First Post")
expect(result.first.status).to eq("published")
```

### Avoid Redundant Assertions with match_array

```ruby
# Good - single comprehensive assertion
expect(current_posts).to match_array([published_post, draft_post])

# Bad - redundant negative assertions
expect(current_posts).to match_array([published_post, draft_post])
expect(current_posts).not_to include(archived_post)  # Redundant!
```

### Use have_attributes for Multiple Assertions

```ruby
# Good
expect(result).to have_attributes(
  title: "My Blog Post",
  status: "published",
  view_count: 5
)

# Bad
expect(result.title).to eq("My Blog Post")
expect(result.status).to eq("published")
expect(result.view_count).to eq(5)
```

### Test State Changes with expect { }.to change { }

```ruby
# Good
expect { subject }.to change { Post.count }.by(1)
expect { subject }.to change { post.reload.status }.from("draft").to("published")

# Bad
subject
expect(Post.count).to eq(initial_count + 1)
```

## Test Structure Guidelines

- **Always use `described_class`** and define a `subject` block
- **Use correct method notation**: `#` for instance methods, `.` for class methods
- **Use one subject per describe block** with `let` variables for parameters
- **Use hierarchical context blocks** that build from general to specific
- **Place `let` variables in the context that first needs them**
- **Use progressive contexts** - start with defaults, only create objects when needed

### Method Notation in Describe Blocks

```ruby
# Good - correct method notation
RSpec.describe BlogPost do
  describe "#published?" do  # Instance method
    subject { blog_post.published? }
  end

  describe ".find_published" do  # Class method
    subject { described_class.find_published }
  end
end

# Bad - incorrect notation
RSpec.describe BlogPost do
  describe ".published?" do  # Wrong! This is an instance method
  end

  describe "#find_published" do  # Wrong! This is a class method
  end
end
```

### One Subject Per Describe Block

```ruby
# Good - single subject with parameterizable arguments
RSpec.describe Blogs::Commands::PublishPost do
  let(:blog) { create(:blog) }
  let(:author) { create(:author) }
  let(:notify_subscribers) { false }

  subject { described_class.call(blog: blog, author: author, notify_subscribers: notify_subscribers) }

  describe "#call" do
    context "when notifications are enabled" do
      let(:notify_subscribers) { true }

      it "sends notifications to subscribers" do
        expect(NotificationWorker).to receive(:perform_async)
        subject
      end
    end
  end
end

# Bad - multiple subject definitions
RSpec.describe Blogs::Commands::PublishPost do
  subject { described_class.call(blog: blog, author: author) }

  context "when notifications are enabled" do
    subject { described_class.call(blog: blog, author: author, notify_subscribers: true) }
  end
end
```

## TDD and JSON Patterns

### Always Write Failing Tests First

Follow TDD cycle: **Red -> Green -> Refactor**

**CRITICAL: Always run tests immediately after writing them to verify they fail for behavioral reasons, not implementation errors.**

### Hash Key Ordering in JSON Expectations

```ruby
# Good - match implementation merge order
expect(json_log).to eq({
  message: "Blog post published",
  caller: "Blogs::Services::Publisher",
  **default_tags,
  **additional_tags
}.to_json)

# Bad - wrong key order causes test failures
expect(json_log).to eq({
  message: "Blog post published",
  **additional_tags,
  **default_tags
}.to_json)
```

## Common Test Issues and Rules

### Avoid Duplicate Test Coverage

Remove redundant test contexts that cover the same scenarios with less comprehensive assertions.

### Prefer Mixed-Type Tests Over Separate Single-Type Tests

```ruby
# Good - single comprehensive mixed test
context "when checking blog access permissions" do
  let(:admin_user) { create(:user, :admin) }
  let(:author_user) { create(:user, :author) }
  let(:reader_user) { create(:user, :reader) }
  let(:users) { [admin_user, author_user, reader_user] }

  it "returns correct permissions for each user type" do
    expect(subject).to match_array([
      have_attributes(user: admin_user, can_edit: true, can_delete: true),
      have_attributes(user: author_user, can_edit: true, can_delete: false),
      have_attributes(user: reader_user, can_edit: false, can_delete: false)
    ])
  end
end

# Bad - redundant separate contexts for single vs mixed types
context "with admin users only" do
  let(:users) { [create(:user, :admin), create(:user, :admin)] }

  it "processes admin permissions" do
    # Covered by mixed-type test
  end
end
```

### General Testing Rules

- Do not test private methods — test the public interface
- Do not test basic Ruby/Rails functionality
- Avoid updating objects in `before` blocks — use `let` with factory traits
- Use one subject per describe block
- Use `let!` for test data setup — avoid creating objects within `it` blocks
- Test both positive and negative scenarios
- Use real database objects and factories over mocks
- Prefer `match_array` with `have_attributes` for collections
- Only parameterize values that get overridden in child contexts
- Integrate new tests into existing structure rather than creating separate contexts
- Follow TDD: write failing tests first, then implement
- Avoid duplicate context names

### AI Agent Test Review Checklist

**When AI agents generate or review tests, check for:**

1. **Multiple tests covering the same default behavior** — keep only the most comprehensive
2. **Duplicate level/state testing across contexts** — consolidate
3. **Identical functionality tested in different calling contexts** — reduce
4. **Basic language feature testing** — remove
5. **Redundant single-type vs mixed-type tests** — prefer mixed

**After generating tests, agents should:**
1. Identify the most comprehensive test for each behavior
2. Remove less comprehensive duplicates
3. Consolidate similar assertions into single comprehensive expectations
4. Verify coverage remains complete after cleanup
5. Run tests to ensure no functionality was lost
