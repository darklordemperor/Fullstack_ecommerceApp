package handler

import (
	"testing"

	"ecommerce/backend/internal/model"
)

func TestValidateRegisterAcceptsValidCustomer(t *testing.T) {
	req := model.RegisterRequest{
		Name:            "Ada",
		Lastname:        "Lovelace",
		Age:             28,
		Email:           "ada@example.com",
		Password:        "abc12345",
		ConfirmPassword: "abc12345",
	}

	errs := validateRegister(req)
	if len(errs) != 0 {
		t.Fatalf("expected no validation errors, got %v", errs)
	}
}

func TestValidateRegisterReturnsFieldErrors(t *testing.T) {
	req := model.RegisterRequest{
		Name:            " ",
		Lastname:        "",
		Age:             17,
		Email:           "not-an-email",
		Password:        "ABC12345",
		ConfirmPassword: "abc12345",
	}

	errs := validateRegister(req)
	for _, field := range []string{"name", "lastname", "age", "email", "password", "confirm_password"} {
		if _, ok := errs[field]; !ok {
			t.Fatalf("expected validation error for %s, got %v", field, errs)
		}
	}
}

func TestValidateRegisterRequiresConfirmPassword(t *testing.T) {
	req := model.RegisterRequest{
		Name:     "Grace",
		Lastname: "Hopper",
		Age:      30,
		Email:    "grace@example.com",
		Password: "abc12345",
	}

	errs := validateRegister(req)
	if got := errs["confirm_password"]; got != "confirm password is required" {
		t.Fatalf("expected confirm password required error, got %q from %v", got, errs)
	}
}
