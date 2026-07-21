package usecase

import (
	"context"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// CartUsecase holds cart-mutation and checkout business rules. It coordinates
// the cart, product, user, and order ports; handlers only parse the request and
// render the result.
type CartUsecase struct {
	carts    domain.CartRepository
	products domain.ProductRepository
	users    domain.UserRepository
	orders   domain.OrderRepository
}

func NewCartUsecase(carts domain.CartRepository, products domain.ProductRepository, users domain.UserRepository, orders domain.OrderRepository) *CartUsecase {
	return &CartUsecase{carts: carts, products: products, users: users, orders: orders}
}

// Get returns the cart with every line re-hydrated from the current product
// record (price/name/image can change after an item was added) and persists the
// refreshed snapshot.
func (u *CartUsecase) Get(ctx context.Context, userID bson.ObjectID) (*model.Cart, error) {
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	cart.Items = normalizeCartItems(cart.Items)
	for i := range cart.Items {
		product, err := u.products.FindByID(ctx, cart.Items[i].ProductID)
		if err != nil {
			return nil, err
		}
		if product != nil {
			cart.Items[i] = cartItemWithProductDetails(cart.Items[i], product)
		}
	}
	if err := u.carts.Save(ctx, cart); err != nil {
		return nil, err
	}
	return cart, nil
}

// Add increases the quantity of an existing line or appends a new one.
func (u *CartUsecase) Add(ctx context.Context, userID, productID bson.ObjectID, quantity int) (*model.Cart, error) {
	product, err := u.products.FindByID(ctx, productID)
	if err != nil {
		return nil, err
	}
	if product == nil {
		return nil, domain.ErrNotFound
	}
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	cart.Items = normalizeCartItems(cart.Items)
	found := false
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity += quantity
			cart.Items[i].SellerID = product.SellerID
			cart.Items[i].SellerName = product.SellerName
			found = true
		}
	}
	if !found {
		cart.Items = append(cart.Items, cartItemFromProduct(product, quantity))
	}
	return u.persist(ctx, cart)
}

// Update sets an existing line to an exact quantity.
func (u *CartUsecase) Update(ctx context.Context, userID, productID bson.ObjectID, quantity int) (*model.Cart, error) {
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	cart.Items = normalizeCartItems(cart.Items)
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity = quantity
			return u.persist(ctx, cart)
		}
	}
	return nil, domain.ErrCartItemNotFound
}

// Remove drops a line from the cart.
func (u *CartUsecase) Remove(ctx context.Context, userID, productID bson.ObjectID) (*model.Cart, error) {
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	next := make([]model.CartItem, 0, len(cart.Items))
	for _, item := range cart.Items {
		if item.ProductID != productID {
			next = append(next, item)
		}
	}
	cart.Items = next
	return u.persist(ctx, cart)
}

// Clear empties the cart.
func (u *CartUsecase) Clear(ctx context.Context, userID bson.ObjectID) (*model.Cart, error) {
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return nil, err
	}
	cart.Items = []model.CartItem{}
	return u.persist(ctx, cart)
}

// Checkout converts the selected cart items into one order per seller, then
// leaves the unselected items in the cart. A nil/empty selection buys the whole
// cart. Returns the number of orders created and the remaining cart.
func (u *CartUsecase) Checkout(ctx context.Context, userID bson.ObjectID, selected map[bson.ObjectID]bool) (int, *model.Cart, error) {
	user, err := u.users.FindByID(ctx, userID)
	if err != nil {
		return 0, nil, err
	}
	if user == nil {
		return 0, nil, domain.ErrNotFound
	}
	cart, err := u.carts.Get(ctx, userID)
	if err != nil {
		return 0, nil, err
	}
	cart.Items = normalizeCartItems(cart.Items)
	if len(cart.Items) == 0 {
		return 0, nil, domain.ErrCartEmpty
	}
	checkoutItems, remaining := splitCheckoutItems(cart.Items, selected)
	if len(checkoutItems) == 0 {
		return 0, nil, domain.ErrNoItemsSelected
	}

	grouped := map[bson.ObjectID][]model.CartItem{}
	for _, item := range checkoutItems {
		product, err := u.products.FindByID(ctx, item.ProductID)
		if err != nil {
			return 0, nil, err
		}
		if product == nil {
			return 0, nil, domain.ErrProductUnavailable
		}
		grouped[product.SellerID] = append(grouped[product.SellerID], item)
	}

	orders := make([]model.Order, 0, len(grouped))
	for sellerID, items := range grouped {
		orders = append(orders, model.Order{
			CustomerID:   userID,
			CustomerName: user.Name + " " + user.Lastname,
			SellerID:     sellerID,
			Items:        items,
			Total:        lineItemsTotal(items),
			Status:       "paid",
		})
	}
	if err := u.orders.CreateMany(ctx, orders); err != nil {
		return 0, nil, err
	}
	cart.Items = remaining
	if err := u.carts.Save(ctx, cart); err != nil {
		return 0, nil, err
	}
	return len(orders), cart, nil
}

// BuyNow places a single-item order immediately without touching the cart.
func (u *CartUsecase) BuyNow(ctx context.Context, userID, productID bson.ObjectID, quantity int) (int, error) {
	user, err := u.users.FindByID(ctx, userID)
	if err != nil {
		return 0, err
	}
	if user == nil {
		return 0, domain.ErrNotFound
	}
	product, err := u.products.FindByID(ctx, productID)
	if err != nil {
		return 0, err
	}
	if product == nil {
		return 0, domain.ErrNotFound
	}
	if quantity > product.Stock {
		return 0, domain.ErrInsufficientStock
	}
	item := cartItemFromProduct(product, quantity)
	order := model.Order{
		CustomerID:   userID,
		CustomerName: user.Name + " " + user.Lastname,
		SellerID:     product.SellerID,
		Items:        []model.CartItem{item},
		Total:        item.Price * float64(item.Quantity),
		Status:       "paid",
	}
	if err := u.orders.CreateMany(ctx, []model.Order{order}); err != nil {
		return 0, err
	}
	return 1, nil
}

// persist normalizes then saves the cart and returns it.
func (u *CartUsecase) persist(ctx context.Context, cart *model.Cart) (*model.Cart, error) {
	cart.Items = normalizeCartItems(cart.Items)
	if err := u.carts.Save(ctx, cart); err != nil {
		return nil, err
	}
	return cart, nil
}

func lineItemsTotal(items []model.CartItem) float64 {
	total := 0.0
	for _, item := range items {
		total += item.Price * float64(item.Quantity)
	}
	return total
}

// cartItemFromProduct builds a fresh cart line from a product.
func cartItemFromProduct(product *model.Product, quantity int) model.CartItem {
	return cartItemWithProductDetails(model.CartItem{ProductID: product.ID, Quantity: quantity}, product)
}

// cartItemWithProductDetails re-projects the display fields of a cart line from
// the authoritative product, preserving only the quantity.
func cartItemWithProductDetails(item model.CartItem, product *model.Product) model.CartItem {
	image := ""
	if len(product.Images) > 0 {
		image = product.Images[0]
	}
	return model.CartItem{
		ProductID:  product.ID,
		SellerID:   product.SellerID,
		SellerName: product.SellerName,
		Name:       product.Name,
		Price:      product.Price,
		Image:      image,
		Quantity:   item.Quantity,
	}
}

// splitCheckoutItems partitions items into (selected, remaining). A nil
// selection means "select everything".
func splitCheckoutItems(items []model.CartItem, selectedProductIDs map[bson.ObjectID]bool) ([]model.CartItem, []model.CartItem) {
	if selectedProductIDs == nil {
		return items, []model.CartItem{}
	}
	selected := make([]model.CartItem, 0, len(selectedProductIDs))
	remaining := make([]model.CartItem, 0, len(items))
	for _, item := range items {
		if selectedProductIDs[item.ProductID] {
			selected = append(selected, item)
			continue
		}
		remaining = append(remaining, item)
	}
	return selected, remaining
}

// normalizeCartItems merges duplicate product lines, summing their quantities.
func normalizeCartItems(items []model.CartItem) []model.CartItem {
	merged := make([]model.CartItem, 0, len(items))
	indexByProductID := make(map[bson.ObjectID]int, len(items))
	for _, item := range items {
		if index, ok := indexByProductID[item.ProductID]; ok {
			merged[index].Quantity += item.Quantity
			continue
		}
		indexByProductID[item.ProductID] = len(merged)
		merged = append(merged, item)
	}
	return merged
}
