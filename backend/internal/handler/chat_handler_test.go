package handler

import "testing"

func TestNormalizeChatMessageRequestRequiresTextOrImage(t *testing.T) {
	text, image, messageType, ok := normalizeChatMessageRequest("   ", "")
	if ok || text != "" || image != "" || messageType != "" {
		t.Fatalf("expected empty request to be invalid, got text=%q image=%q type=%q ok=%v", text, image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestAcceptsTrimmedText(t *testing.T) {
	text, image, messageType, ok := normalizeChatMessageRequest("  hello  ", "")
	if !ok || text != "hello" || image != "" || messageType != "text" {
		t.Fatalf("expected text message, got text=%q image=%q type=%q ok=%v", text, image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestRejectsLongText(t *testing.T) {
	longText := make([]byte, 2001)
	for i := range longText {
		longText[i] = 'a'
	}
	_, _, _, ok := normalizeChatMessageRequest(string(longText), "")
	if ok {
		t.Fatal("expected long text to be invalid")
	}
}

func TestNormalizeChatMessageRequestAcceptsImageDataURL(t *testing.T) {
	_, image, messageType, ok := normalizeChatMessageRequest("", "data:image/jpeg;base64,abcd")
	if !ok || image == "" || messageType != "image" {
		t.Fatalf("expected image message, got image=%q type=%q ok=%v", image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestRejectsUnsupportedImageDataURL(t *testing.T) {
	_, _, _, ok := normalizeChatMessageRequest("", "data:image/gif;base64,abcd")
	if ok {
		t.Fatal("expected unsupported image data URL to be invalid")
	}
}
