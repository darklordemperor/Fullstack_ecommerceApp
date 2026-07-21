package usecase

import (
	"testing"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

func TestNormalizeCartItemsMergesDuplicateProducts(t *testing.T) {
	productID := bson.NewObjectID()
	otherID := bson.NewObjectID()

	items := normalizeCartItems([]model.CartItem{
		{ProductID: productID, Name: "Keyboard", Price: 1200, Quantity: 1},
		{ProductID: otherID, Name: "Mouse", Price: 450, Quantity: 1},
		{ProductID: productID, Name: "Keyboard", Price: 1200, Quantity: 2},
	})

	if len(items) != 2 {
		t.Fatalf("expected 2 unique cart items, got %d: %#v", len(items), items)
	}
	if items[0].ProductID != productID || items[0].Quantity != 3 {
		t.Fatalf("expected first product quantity 3, got %#v", items[0])
	}
	if items[1].ProductID != otherID || items[1].Quantity != 1 {
		t.Fatalf("expected second product quantity 1, got %#v", items[1])
	}
}

func TestSplitCheckoutItemsKeepsUnselectedCartItems(t *testing.T) {
	selectedID := bson.NewObjectID()
	keptID := bson.NewObjectID()

	selected, remaining := splitCheckoutItems([]model.CartItem{
		{ProductID: selectedID, Name: "Keyboard", Price: 1200, Quantity: 1},
		{ProductID: keptID, Name: "Mouse", Price: 450, Quantity: 1},
	}, map[bson.ObjectID]bool{selectedID: true})

	if len(selected) != 1 || selected[0].ProductID != selectedID {
		t.Fatalf("expected only selected product for checkout, got %#v", selected)
	}
	if len(remaining) != 1 || remaining[0].ProductID != keptID {
		t.Fatalf("expected unselected product to stay in cart, got %#v", remaining)
	}
}

func TestCartItemFromProductIncludesSellerShopData(t *testing.T) {
	productID := bson.NewObjectID()
	sellerID := bson.NewObjectID()

	item := cartItemFromProduct(&model.Product{
		ID:         productID,
		SellerID:   sellerID,
		SellerName: "Ada Shop",
		Name:       "Keyboard",
		Price:      1200,
		Images:     []string{"image-1"},
	}, 2)

	if item.ProductID != productID || item.SellerID != sellerID {
		t.Fatalf("expected product and seller ids copied, got %#v", item)
	}
	if item.SellerName != "Ada Shop" {
		t.Fatalf("expected seller name copied, got %#v", item)
	}
	if item.Image != "image-1" || item.Quantity != 2 {
		t.Fatalf("expected image and quantity copied, got %#v", item)
	}
}

func TestCartItemWithProductDetailsHydratesLegacyCartItem(t *testing.T) {
	productID := bson.NewObjectID()
	sellerID := bson.NewObjectID()

	item := cartItemWithProductDetails(model.CartItem{
		ProductID: productID,
		Quantity:  3,
	}, &model.Product{
		ID:         productID,
		SellerID:   sellerID,
		SellerName: "Grace Store",
		Name:       "Monitor",
		Price:      3500,
		Images:     []string{"image-2"},
	})

	if item.SellerName != "Grace Store" || item.SellerID != sellerID {
		t.Fatalf("expected seller data hydrated, got %#v", item)
	}
	if item.Name != "Monitor" || item.Price != 3500 || item.Image != "image-2" {
		t.Fatalf("expected product display data hydrated, got %#v", item)
	}
	if item.Quantity != 3 {
		t.Fatalf("expected quantity preserved, got %#v", item)
	}
}
