package handler

import (
	"net/http"

	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type CartHandler struct {
	carts    *repository.CartRepository
	products *repository.ProductRepository
	users    *repository.UserRepository
	orders   *repository.OrderRepository
}

func NewCartHandler(carts *repository.CartRepository, products *repository.ProductRepository, users *repository.UserRepository, orders *repository.OrderRepository) *CartHandler {
	return &CartHandler{carts: carts, products: products, users: users, orders: orders}
}

func (h *CartHandler) Get(c *gin.Context) {
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = normalizeCartItems(cart.Items)
	for i := range cart.Items {
		product, err := h.products.FindByID(c.Request.Context(), cart.Items[i].ProductID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart product"})
			return
		}
		if product != nil {
			cart.Items[i] = cartItemWithProductDetails(cart.Items[i], product)
		}
	}
	if err := h.carts.Save(c.Request.Context(), cart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart loaded"})
}

func (h *CartHandler) Add(c *gin.Context) {
	var req model.CartQuantityRequest
	if !bindCartQuantity(c, &req) {
		return
	}
	productID, _ := bson.ObjectIDFromHex(req.ProductID)
	product, err := h.products.FindByID(c.Request.Context(), productID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
		return
	}
	if product == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = normalizeCartItems(cart.Items)
	found := false
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity += req.Quantity
			cart.Items[i].SellerID = product.SellerID
			cart.Items[i].SellerName = product.SellerName
			found = true
		}
	}
	if !found {
		cart.Items = append(cart.Items, cartItemFromProduct(product, req.Quantity))
	}
	h.saveCart(c, cart, "cart updated")
}

func (h *CartHandler) Update(c *gin.Context) {
	var req model.CartQuantityRequest
	if !bindCartQuantity(c, &req) {
		return
	}
	productID, _ := bson.ObjectIDFromHex(req.ProductID)
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = normalizeCartItems(cart.Items)
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity = req.Quantity
			h.saveCart(c, cart, "cart updated")
			return
		}
	}
	c.JSON(http.StatusNotFound, gin.H{"error": "cart item not found"})
}

func (h *CartHandler) Remove(c *gin.Context) {
	productID, err := bson.ObjectIDFromHex(c.Param("product_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	next := make([]model.CartItem, 0, len(cart.Items))
	for _, item := range cart.Items {
		if item.ProductID != productID {
			next = append(next, item)
		}
	}
	cart.Items = next
	h.saveCart(c, cart, "item removed")
}

func (h *CartHandler) Clear(c *gin.Context) {
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = []model.CartItem{}
	h.saveCart(c, cart, "cart cleared")
}

func (h *CartHandler) Checkout(c *gin.Context) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	user, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil || user == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load customer"})
		return
	}
	cart, err := h.carts.Get(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = normalizeCartItems(cart.Items)
	if len(cart.Items) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cart is empty"})
		return
	}
	selectedProductIDs, ok := bindCheckoutProductIDs(c)
	if !ok {
		return
	}
	checkoutItems, remainingItems := splitCheckoutItems(cart.Items, selectedProductIDs)
	if len(checkoutItems) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "select at least one cart item"})
		return
	}

	grouped := map[bson.ObjectID][]model.CartItem{}
	for _, item := range checkoutItems {
		product, err := h.products.FindByID(c.Request.Context(), item.ProductID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
			return
		}
		if product == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "one product in your cart is no longer available"})
			return
		}
		grouped[product.SellerID] = append(grouped[product.SellerID], item)
	}

	orders := make([]model.Order, 0, len(grouped))
	for sellerID, items := range grouped {
		total := 0.0
		for _, item := range items {
			total += item.Price * float64(item.Quantity)
		}
		orders = append(orders, model.Order{
			CustomerID:   userID,
			CustomerName: user.Name + " " + user.Lastname,
			SellerID:     sellerID,
			Items:        items,
			Total:        total,
			Status:       "paid",
		})
	}
	if err := h.orders.CreateMany(c.Request.Context(), orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create order"})
		return
	}
	cart.Items = remainingItems
	if err := h.carts.Save(c.Request.Context(), cart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to clear cart"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"orders_created": len(orders), "cart": cart}, "message": "checkout complete"})
}

func (h *CartHandler) BuyNow(c *gin.Context) {
	var req model.CartQuantityRequest
	if !bindCartQuantity(c, &req) {
		return
	}
	userID := c.MustGet("user_id").(bson.ObjectID)
	user, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil || user == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load customer"})
		return
	}
	productID, _ := bson.ObjectIDFromHex(req.ProductID)
	product, err := h.products.FindByID(c.Request.Context(), productID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
		return
	}
	if product == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	if req.Quantity > product.Stock {
		c.JSON(http.StatusBadRequest, gin.H{"error": "quantity is greater than available stock"})
		return
	}
	item := cartItemFromProduct(product, req.Quantity)
	order := model.Order{
		CustomerID:   userID,
		CustomerName: user.Name + " " + user.Lastname,
		SellerID:     product.SellerID,
		Items:        []model.CartItem{item},
		Total:        item.Price * float64(item.Quantity),
		Status:       "paid",
	}
	if err := h.orders.CreateMany(c.Request.Context(), []model.Order{order}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create order"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"orders_created": 1}, "message": "checkout complete"})
}

func (h *CartHandler) saveCart(c *gin.Context, cart *model.Cart, message string) {
	cart.Items = normalizeCartItems(cart.Items)
	if err := h.carts.Save(c.Request.Context(), cart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": message})
}

func bindCartQuantity(c *gin.Context, req *model.CartQuantityRequest) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return false
	}
	if _, err := bson.ObjectIDFromHex(req.ProductID); err != nil || req.Quantity < 1 || req.Quantity > 99 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "valid product_id and quantity 1-99 are required"})
		return false
	}
	return true
}

func cartItemFromProduct(product *model.Product, quantity int) model.CartItem {
	return cartItemWithProductDetails(model.CartItem{
		ProductID: product.ID,
		Quantity:  quantity,
	}, product)
}

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

func bindCheckoutProductIDs(c *gin.Context) (map[bson.ObjectID]bool, bool) {
	var req model.CartCheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		if err.Error() == "EOF" {
			return nil, true
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return nil, false
	}
	if len(req.ProductIDs) == 0 {
		return nil, true
	}
	selected := make(map[bson.ObjectID]bool, len(req.ProductIDs))
	for _, rawID := range req.ProductIDs {
		id, err := bson.ObjectIDFromHex(rawID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "valid product_ids are required"})
			return nil, false
		}
		selected[id] = true
	}
	return selected, true
}

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
