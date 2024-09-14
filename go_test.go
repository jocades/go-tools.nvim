package go_test

import (
	"fmt"
	"testing"
)

func TestNot() {}

func TestStuff(t *testing.T) {
	fmt.Println("testing...")
}

func TestOtherStuff(t *testing.T) {
	t.Error("got x, want y")
}
