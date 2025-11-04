# E-Commerce Application Example

This example demonstrates an e-commerce application with SimpleAuthorize, showcasing:

- User roles: Admin, Customer
- Products with visibility and pricing controls
- Orders with status-based authorization
- Cart management
- Admin dashboard access

## Models

- **User**: Has role (admin, customer)
- **Product**: Has price, inventory, active status
- **Order**: Belongs to User, has status (pending, paid, shipped, delivered, cancelled)
- **Cart**: Belongs to User
- **CartItem**: Belongs to Cart and Product

## User Roles

### Admin
- Full access to all resources
- Can manage products (CRUD)
- Can view and manage all orders
- Can update order status
- Can view analytics

### Customer
- Can view active products
- Can manage their own cart
- Can create orders
- Can view their own orders
- Can cancel pending orders
- Cannot see other customers' data

### Guest (Not Logged In)
- Can view active products
- Cannot add to cart or create orders

## Authorization Rules

### Products

| Action  | Guest | Customer | Admin |
|---------|-------|----------|-------|
| index   | ✓     | ✓        | ✓     |
| show    | ✓     | ✓        | ✓     |
| create  | ✗     | ✗        | ✓     |
| update  | ✗     | ✗        | ✓     |
| destroy | ✗     | ✗        | ✓     |

### Orders

| Action  | Guest | Customer | Admin |
|---------|-------|----------|-------|
| index   | ✗     | ✓ (own)  | ✓ (all) |
| show    | ✗     | ✓ (own)  | ✓     |
| create  | ✗     | ✓        | ✓     |
| update  | ✗     | ✗        | ✓     |
| cancel  | ✗     | ✓ (own, pending only) | ✓ |
| ship    | ✗     | ✗        | ✓     |

### Cart

| Action  | Guest | Customer | Admin |
|---------|-------|----------|-------|
| show    | ✗     | ✓ (own)  | ✓     |
| add_item | ✗     | ✓ (own)  | ✓     |
| remove_item | ✗ | ✓ (own)  | ✓     |
| checkout | ✗    | ✓ (own)  | ✓     |

## Key Features

### Product Scoping
```ruby
class ProductPolicy::Scope
  def resolve
    if admin?
      scope.all  # Admins see all products including inactive
    else
      scope.where(active: true)  # Customers see only active products
    end
  end
end
```

### Order Ownership
```ruby
def show?
  admin? || owner?  # Customers can only see their own orders
end

def cancel?
  return true if admin?
  owner? && record.pending?  # Customers can only cancel pending orders
end
```

### Price Visibility
```ruby
def visible_attributes
  if admin?
    [:id, :name, :description, :price, :cost, :inventory, :active]
  else
    [:id, :name, :description, :price]  # Hide cost and inventory from customers
  end
end
```

### Attribute-Level Authorization
- **Admin can edit:** All product attributes including cost, price, inventory
- **Customers can edit:** Nothing on products (read-only)
- **Admin can edit:** Order status, shipping info
- **Customers can edit:** Shipping address (before order is shipped)

## Usage Example

```ruby
class ProductsController < ApplicationController
  def index
    @products = policy_scope(Product)  # Auto-filters to active for customers
  end

  def show
    @product = Product.find(params[:id])
    authorize @product
    @price = policy(@product).attribute_visible?(:cost) ? @product.cost : @product.price
  end
end

class OrdersController < ApplicationController
  def index
    @orders = policy_scope(Order)  # Shows only customer's own orders
  end

  def cancel
    @order = Order.find(params[:id])
    authorize @order, :cancel?
    @order.update!(status: :cancelled)
    redirect_to @order, notice: "Order cancelled"
  end
end
```

## Testing

```ruby
test "customers can only see their own orders" do
  customer = User.new(id: 1, role: "customer")
  own_order = Order.new(user_id: 1)
  other_order = Order.new(user_id: 2)

  assert_permit_action OrderPolicy.new(customer, own_order), :show
  assert_forbid_action OrderPolicy.new(customer, other_order), :show
end

test "customers can only cancel pending orders" do
  customer = User.new(id: 1, role: "customer")
  pending_order = Order.new(user_id: 1, status: :pending)
  shipped_order = Order.new(user_id: 1, status: :shipped)

  assert_permit_action OrderPolicy.new(customer, pending_order), :cancel
  assert_forbid_action OrderPolicy.new(customer, shipped_order), :cancel
end
```

## Key Takeaways

1. **Ownership-Based**: Customers can only access their own resources
2. **Status-Based**: Order actions depend on order status
3. **Visibility Control**: Hide sensitive data (cost, inventory) from customers
4. **Role Separation**: Clear admin vs customer permissions
5. **Business Logic**: Authorization includes business rules (can't cancel shipped orders)
