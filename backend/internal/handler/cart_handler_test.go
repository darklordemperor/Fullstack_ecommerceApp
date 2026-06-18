package handler

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
