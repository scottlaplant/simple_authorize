# Blog Application Example

This example demonstrates a complete blog application with SimpleAuthorize, showcasing:

- User roles: Admin, Author, Moderator, Viewer
- Posts with visibility and editing controls
- Comments with moderation
- Draft/published status
- Owner-based permissions

## Models

- **User**: Has a role (admin, author, moderator, viewer)
- **Post**: Belongs to author (User), has published status
- **Comment**: Belongs to Post and User, has approved status

## User Roles

### Admin
- Can do everything
- Full access to all posts and comments
- Can manage users

### Author
- Can create and manage their own posts
- Can publish/unpublish their own posts
- Can moderate comments on their posts
- Can view all published posts

### Moderator
- Can moderate all comments
- Can view all posts
- Cannot edit posts

### Viewer (Regular User)
- Can view published posts
- Can comment on posts
- Can edit their own comments
- Can view approved comments

### Guest (Not Logged In)
- Can view published posts
- Can view approved comments
- Cannot comment or create content

## Authorization Rules

### Posts

| Action  | Guest | Viewer | Author | Moderator | Admin |
|---------|-------|--------|--------|-----------|-------|
| index   | ✓     | ✓      | ✓      | ✓         | ✓     |
| show    | ✓ (published) | ✓ (published) | ✓ (own + published) | ✓ | ✓ |
| create  | ✗     | ✗      | ✓      | ✗         | ✓     |
| update  | ✗     | ✗      | ✓ (own) | ✗         | ✓     |
| destroy | ✗     | ✗      | ✓ (own) | ✗         | ✓     |
| publish | ✗     | ✗      | ✓ (own) | ✗         | ✓     |

### Comments

| Action  | Guest | Viewer | Author | Moderator | Admin |
|---------|-------|--------|--------|-----------|-------|
| index   | ✓ (approved) | ✓ (approved) | ✓ | ✓ | ✓ |
| show    | ✓ (approved) | ✓ (approved) | ✓ | ✓ | ✓ |
| create  | ✗     | ✓      | ✓      | ✓         | ✓     |
| update  | ✗     | ✓ (own) | ✓ (own) | ✗         | ✓     |
| destroy | ✗     | ✗      | ✗      | ✓         | ✓     |
| approve | ✗     | ✗      | ✓ (on own posts) | ✓ | ✓ |

## Attribute-Level Authorization

### Post Attributes

**Visible to everyone:**
- `id`, `title`, `excerpt`

**Visible to authenticated users:**
- `id`, `title`, `excerpt`, `body`, `created_at`

**Visible to authors (own posts) and admins:**
- All attributes including `published`, `user_id`

**Editable by authors (own posts):**
- `title`, `body`, `excerpt`

**Editable by admins:**
- All attributes including `published`, `user_id`

### Comment Attributes

**Visible to everyone:**
- `id`, `body`, `created_at` (approved comments only)

**Editable by comment owners:**
- `body`

**Editable by moderators/admins:**
- `body`, `approved`

## Usage Examples

### Controller Example

```ruby
class PostsController < ApplicationController
  include SimpleAuthorize::Controller

  def index
    @posts = policy_scope(Post)
  end

  def show
    @post = Post.find(params[:id])
    authorize @post
    @visible_attrs = visible_attributes(@post)
  end

  def create
    @post = Post.new
    authorize @post
    @post.assign_attributes(policy_params(@post))
    @post.user = current_user

    if @post.save
      redirect_to @post
    else
      render :new
    end
  end

  def update
    @post = Post.find(params[:id])
    authorize @post

    if @post.update(policy_params(@post))
      redirect_to @post
    else
      render :edit
    end
  end

  def publish
    @post = Post.find(params[:id])
    authorize @post, :publish?

    @post.update(published: true)
    redirect_to @post, notice: "Post published!"
  end
end
```

### View Example

```erb
<!-- app/views/posts/show.html.erb -->
<h1><%= @post.title %></h1>

<% if policy(@post).update? %>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>

<% if policy(@post).destroy? %>
  <%= link_to "Delete", post_path(@post), method: :delete %>
<% end %>

<% if policy(@post).publish? && !@post.published? %>
  <%= link_to "Publish", publish_post_path(@post), method: :post %>
<% end %>

<div class="post-content">
  <% visible_attributes(@post).each do |attr| %>
    <p><strong><%= attr.to_s.humanize %>:</strong> <%= @post.send(attr) %></p>
  <% end %>
</div>

<!-- Comments section -->
<h2>Comments</h2>
<% policy_scope(@post.comments).each do |comment| %>
  <div class="comment">
    <%= comment.body %>
    <% if policy(comment).approve? && !comment.approved? %>
      <%= link_to "Approve", approve_comment_path(comment), method: :post %>
    <% end %>
  </div>
<% end %>
```

## Testing

See `tests/` directory for comprehensive policy tests demonstrating all authorization scenarios.

## Key Takeaways

1. **Role-Based**: Different user roles have different permission levels
2. **Owner-Based**: Users can manage their own content
3. **Status-Based**: Published vs draft affects visibility
4. **Attribute Control**: Fine-grained control over what users can see/edit
5. **Scope Filtering**: Automatically filter collections based on permissions
6. **Custom Actions**: Support for non-CRUD actions like `publish?`
