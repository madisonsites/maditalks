# Contributing to Guidelines

## Documentation Standards

When adding examples to any guideline document, follow these standards:

### **Domain Examples**
Use a distinct domain (e.g., Blog and Posts) to avoid confusion with the real codebase, while preserving context-specific technical details when necessary.

**Good Examples:**
```ruby
# Using Blog domain
class Blog::Commands::PublishPost
  extend Callable

  def initialize(post:, author:, publish_at: Time.current)
    @post = post
    @author = author
    @publish_at = publish_at
  end
end

# Test examples
let(:post) { create(:post, :draft) }
let(:author) { create(:user, :author) }
```

**Avoid:**
```ruby
# Don't reference actual codebase classes
class Orders::Commands::ApproveOrder  # Too specific to our domain
class UserService  # Could confuse with real UserService
```

### **Technical Context Preservation**
While using blog examples, preserve actual technical patterns and implementation details that are relevant to your codebase:

- Real gem names and methods (e.g., `FactoryBot.create`, `RSpec.describe`)
- Actual Rails patterns (e.g., `ActiveRecord` relationships, controller patterns)
- Specific testing frameworks and tools you use
- Real file paths and directory structures when relevant

### **ERB Comment Syntax**
When writing examples that include ERB templates, always use the correct comment syntax:

**Use ERB comments in ERB blocks:**
```erb
<%# This is a server-side comment that won't appear in rendered HTML %>
<%= turbo_frame_tag "blog_content" do %>
  <%# Another ERB comment explaining the logic %>
  <%= render "blog_posts/content", post: @post %>
<% end %>
```

**Avoid HTML comments in ERB blocks (unless intentionally showing wrong approach):**
```erb
<!-- This will appear in the browser's view source -->
<%= turbo_frame_tag "blog_content" do %>
  <!-- This comment will be visible to end users -->
  <%= render "blog_posts/content", post: @post %>
<% end %>
```

**When to use each:**
- **ERB comments `<%# %>`**: Server-side documentation, development notes, explanations that shouldn't reach end users
- **HTML comments `<!-- -->`**: Comments that should appear in rendered HTML for debugging or external tools

### **Consistency Across Guidelines**
- Use the same Blog domain entities across all guideline files
- Common entities: `Post`, `Author`, `Comment`, `Category`, `Tag`
- Common services: `BlogService`, `AuthorService`, `CommentService`
- Common commands: `Blog::Commands::PublishPost`, `Blog::Commands::ArchivePost`

This ensures examples are cohesive when developers read multiple guideline files.

### **Integration Over Addition**
When contributing new guidelines or examples:

**Preferred Approach:**
- **Integrate into existing sections** when the content fits naturally
- **Enhance existing examples** rather than creating duplicate scenarios
- **Expand existing patterns** with additional context or edge cases
- **Build on established structure** rather than fragmenting topics

**Avoid:**
- Creating new sections when existing ones cover the same topic area
- Duplicating similar examples in different sections
- Breaking up cohesive topics across multiple sections

**Only create new sections when:**
- The content addresses a genuinely new topic area
- Existing sections would become too broad or unfocused
- The new content requires a fundamentally different organizational approach

### **Section Index Maintenance**
Some guideline files contain a `<!-- Section Index -->` HTML comment near the top listing each major section with its line range and keywords. Agents and developers use these indexes to load only the sections they need instead of reading the entire file.

**When your change adds, removes, or moves a section** in a file that has a Section Index:
- Update the line ranges for every affected section in the index
- Add or remove rows for any new or deleted sections
- Update keywords if the section's scope changed

The easiest way to verify: after editing, grep for section headings (`^### ` or `^## `) and compare the line numbers against the index table.
